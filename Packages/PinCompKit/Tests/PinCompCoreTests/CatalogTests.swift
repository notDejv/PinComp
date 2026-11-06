import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import PinCompCore

@Suite("Catalog")
struct CatalogTests {
    @Test func resolvesUserCodeToNineChampions() async throws {
        let code = try TeamPlannerCode(parsing: SampleCatalog.userCode)
        let resolution = try await FakeCatalog().resolve(code)
        #expect(resolution.unknown.isEmpty)
        #expect(resolution.champions.map(\.name) == [
            "Rakan", "Yorick", "Fiddlesticks", "Lillia", "Ahri", "Sett", "Zyra", "Taric", "Gnar",
        ])
    }

    @Test func unknownCodesKeepTheirSlot() throws {
        let code = try TeamPlannerCode(parsing: "02420FFF4004123E942A43C430401000TFTSet18")
        let resolution = Resolution(code: code, catalog: SampleCatalog.set18)
        #expect(resolution.unknown == [0xFFF])
        #expect(resolution.championIDs[1] == "?4095")
        #expect(resolution.compSlots[1].champion == nil)
        #expect(resolution.champions.count == 8)
    }

    @Test func decodesPublishedShape() throws {
        let json = """
        {"set":"TFTSet18","generatedAt":"2026-11-06T12:00:00Z","champions":[
          {"id":"DA_18_Ahri","name":"Ahri","cost":4,"plannerCode":1001,"icon":"https://example.com/ahri.png"}]}
        """
        let catalog = try JSONDecoder().decode(SetCatalog.self, from: Data(json.utf8))
        #expect(catalog.champion(plannerCode: 1001)?.iconURL.absoluteString == "https://example.com/ahri.png")
    }
}

@Suite("CatalogStore")
struct CatalogStoreTests {
    /// Serves a fake Pages site and counts icon downloads.
    final class Server: @unchecked Sendable {
        private let lock = NSLock()
        private var iconHits = 0
        private var generatedAt = "A"
        private var failingIcons = false

        var icons: Int { lock.withLock { iconHits } }
        func setGeneratedAt(_ value: String) { lock.withLock { generatedAt = value } }
        func setFailingIcons(_ value: Bool) { lock.withLock { failingIcons = value } }

        /// A real 256 px PNG so the island copies can be generated.
        static let png: Data = {
            let context = CGContext(
                data: nil, width: 256, height: 256, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )!
            context.setFillColor(CGColor(red: 1, green: 0.7, blue: 0.2, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 256, height: 256))
            let output = NSMutableData()
            let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil)!
            CGImageDestinationAddImage(destination, context.makeImage()!, nil)
            CGImageDestinationFinalize(destination)
            return output as Data
        }()

        func fetch(_ url: URL) throws -> Data {
            try lock.withLock {
                switch url.lastPathComponent {
                case "index.json":
                    return try JSONEncoder().encode(SampleCatalog.index)
                case "champions.json":
                    let base = SampleCatalog.set18
                    return try JSONEncoder().encode(SetCatalog(set: base.set, generatedAt: generatedAt, champions: base.champions))
                default:
                    iconHits += 1
                    if failingIcons { throw URLError(.notConnectedToInternet) }
                    return Self.png
                }
            }
        }
    }

    private func makeStore(_ server: Server) -> (CatalogStore, CatalogCache) {
        let root = FileManager.default.temporaryDirectory.appending(path: "PinCompTests-\(UUID().uuidString)")
        let cache = CatalogCache(root: root)
        return (CatalogStore(cache: cache, fetch: { try server.fetch($0) }), cache)
    }

    @Test func refreshCachesJSONAndIcons() async throws {
        let server = Server()
        let (store, cache) = makeStore(server)
        let index = try await store.refresh()
        #expect(index.latest == "TFTSet18")
        #expect(cache.loadIndex() == SampleCatalog.index)
        #expect(cache.loadCatalog(set: "TFTSet18")?.champions.count == SampleCatalog.set18.champions.count)
        #expect(SampleCatalog.set18.champions.allSatisfy { cache.cachedIcon(set: "TFTSet18", championID: $0.id) != nil })
        #expect(server.icons == SampleCatalog.set18.champions.count)
        #expect(await store.lastUpdated() != nil)
    }

    @Test func savesIslandSizedCopies() async throws {
        let server = Server()
        let (store, cache) = makeStore(server)
        try await store.refresh()
        let id = try #require(SampleCatalog.set18.champions.first?.id)
        for size in IslandIconSize.allCases {
            let url = try #require(cache.cachedIslandIcon(set: "TFTSet18", championID: id, size: size))
            let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
            let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
            #expect(image.width == size.pixels && image.height == size.pixels)
        }
    }

    @Test func missingIslandCopiesAreRebuiltOffline() async throws {
        let server = Server()
        let (store, cache) = makeStore(server)
        try await store.refresh()
        let id = try #require(SampleCatalog.set18.champions.first?.id)
        try FileManager.default.removeItem(at: cache.islandIconURL(set: "TFTSet18", championID: id, size: .compact))

        let offline = CatalogStore(cache: cache, fetch: { _ in throw URLError(.notConnectedToInternet) })
        _ = try await offline.catalog(for: "TFTSet18")
        #expect(cache.cachedIslandIcon(set: "TFTSet18", championID: id, size: .compact) != nil)
    }

    @Test func iconsRedownloadOnlyWhenGeneratedAtChanges() async throws {
        let server = Server()
        let (store, _) = makeStore(server)
        let count = SampleCatalog.set18.champions.count
        try await store.refresh()
        try await store.refresh()
        #expect(server.icons == count)
        server.setGeneratedAt("B")
        try await store.refresh()
        #expect(server.icons == 2 * count)
    }

    @Test func failedIconsAreReportedAndRetried() async throws {
        let server = Server()
        let (store, cache) = makeStore(server)
        server.setFailingIcons(true)
        await #expect(throws: CatalogError.iconsIncomplete(missing: SampleCatalog.set18.champions.count)) {
            try await store.refresh()
        }
        server.setFailingIcons(false)
        try await store.refresh()
        #expect(SampleCatalog.set18.champions.allSatisfy { cache.cachedIcon(set: "TFTSet18", championID: $0.id) != nil })
    }

    @Test func cachedDataServesOffline() async throws {
        let server = Server()
        let (store, cache) = makeStore(server)
        try await store.refresh()
        let offline = CatalogStore(cache: cache, fetch: { _ in throw URLError(.notConnectedToInternet) })
        #expect(try await offline.index().latest == "TFTSet18")
        #expect(try await offline.catalog(for: "TFTSet18").champions.isEmpty == false)
    }
}

@Suite("ActiveTrait")
struct ActiveTraitTests {
    private let slots = Resolution(
        code: try! TeamPlannerCode(parsing: SampleCatalog.userCode),
        catalog: SampleCatalog.set18
    ).compSlots

    @Test func userCompTraits() {
        let active = ActiveTrait.compute(slots: slots, traits: SampleCatalog.set18.traitsByID)
        #expect(active.first?.trait.name == "Blossom")
        #expect(active.first?.count == 3)
        #expect(active.count == 11)
        // Below their first breakpoint.
        #expect(!active.contains { $0.trait.name == "Elderwood" || $0.trait.name == "Sprykin" })
    }

    @Test func duplicateChampionsCountOnce() {
        let doubled = slots + slots.map { CompSlot(index: $0.index + 10, championID: $0.championID, champion: $0.champion) }
        let once = ActiveTrait.compute(slots: slots, traits: SampleCatalog.set18.traitsByID)
        #expect(ActiveTrait.compute(slots: doubled, traits: SampleCatalog.set18.traitsByID) == once)
    }

    @Test func decodesCatalogWithoutTraits() throws {
        let json = """
        {"set":"TFTSet18","generatedAt":"x","champions":[
          {"id":"A","name":"A","cost":1,"plannerCode":1,"icon":"https://example.com/a.png"}]}
        """
        let catalog = try JSONDecoder().decode(SetCatalog.self, from: Data(json.utf8))
        #expect(catalog.traits.isEmpty)
        #expect(catalog.champions.first?.traits == [])
    }
}
