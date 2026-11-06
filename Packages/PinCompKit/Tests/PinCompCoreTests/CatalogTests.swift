import Foundation
import Testing
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
                    return Data("png".utf8)
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
