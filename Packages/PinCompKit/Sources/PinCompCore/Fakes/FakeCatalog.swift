import Foundation

/// `CatalogProviding` backed by in-memory catalogs. Never touches the network or disk.
public actor FakeCatalog: CatalogProviding {
    public private(set) var currentIndex: CatalogIndex
    private var catalogs: [String: SetCatalog]
    private var updated: Date?
    public private(set) var refreshCount = 0

    public init(index: CatalogIndex = SampleCatalog.index, catalogs: [SetCatalog] = [SampleCatalog.set18]) {
        currentIndex = index
        self.catalogs = Dictionary(catalogs.map { ($0.set, $0) }, uniquingKeysWith: { _, last in last })
        updated = .now
    }

    public struct MissingSet: Error, Equatable {
        public let set: String
    }

    public func index() -> CatalogIndex { currentIndex }

    public func catalog(for set: String) throws -> SetCatalog {
        guard let catalog = catalogs[set] else { throw MissingSet(set: set) }
        return catalog
    }

    public func refresh() -> CatalogIndex {
        refreshCount += 1
        updated = .now
        return currentIndex
    }

    public func lastUpdated() -> Date? { updated }

    public func setIndex(_ index: CatalogIndex) { currentIndex = index }
}

@MainActor
extension CompRepository {
    /// In-memory repository, optionally filled with sample comps.
    public static func preview(withSamples: Bool = true) -> CompRepository {
        do {
            let repository = CompRepository(container: try makeContainer(inMemory: true))
            if withSamples { try repository.insertSamples() }
            return repository
        } catch {
            fatalError("Cannot create preview store: \(error)")
        }
    }

    func insertSamples() throws {
        let code = try TeamPlannerCode(parsing: SampleCatalog.userCode)
        let resolution = Resolution(code: code, catalog: SampleCatalog.set18)
        try add(
            name: Comp.defaultName(for: resolution.champions),
            set: code.set,
            rawCode: SampleCatalog.userCode,
            championIDs: resolution.championIDs
        )
        let rest = SampleCatalog.set18.champions.suffix(4)
        try add(
            name: "Sample reroll",
            set: "TFTSet18",
            rawCode: "sample-reroll",
            championIDs: rest.map(\.id) + [Comp.unknownID(plannerCode: 4095)]
        )
    }
}
