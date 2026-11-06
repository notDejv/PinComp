import Foundation
import Observation
import PinCompActivity
import PinCompCore

/// Why a pasted code can't be added. Messages are shown inline.
enum CompCodeError: Error, Equatable, LocalizedError {
    case notACode
    case olderSet(String)
    case notAvailable(String)
    case offline

    var errorDescription: String? {
        switch self {
        case .notACode:
            "That doesn't look like a TFT team code."
        case .olderSet(let set):
            "This comp is from \(TFTSet.displayName(of: set)), an older set. Copy a code from the current set."
        case .notAvailable(let set):
            "Data for \(TFTSet.displayName(of: set)) isn't available yet."
        case .offline:
            "Couldn't load champion data. Check your connection and try again."
        }
    }
}

/// App-wide state and the services the screens share.
@MainActor
@Observable
final class AppModel {
    let catalog: any CatalogProviding
    let repository: CompRepository
    let pins: any PinControlling

    /// `index.json` → `latest`. Only comps of this set are listed and cycled.
    private(set) var currentSet: String?
    private(set) var lastUpdated: Date?
    private(set) var isRefreshing = false
    private(set) var refreshError: String?
    private(set) var hasStarted = false

    @ObservationIgnored private var lookups: [String: [String: Champion]] = [:]
    @ObservationIgnored private var traitLookups: [String: [String: Trait]] = [:]
    /// Bumped when catalogs change so boards re-render with new data.
    private(set) var catalogVersion = 0

    /// Automatic refresh on launch when the cache is older than this.
    private let autoRefreshInterval: TimeInterval = 6 * 60 * 60

    init(catalog: any CatalogProviding, repository: CompRepository, pins: any PinControlling) {
        self.catalog = catalog
        self.repository = repository
        self.pins = pins
    }

    /// The app's single instance; intents reach it through `AppActions`.
    static let shared = AppModel.live()

    static func live() -> AppModel {
        AppModel(catalog: CatalogStore.shared, repository: .shared, pins: PinService.shared)
    }

    // MARK: Catalog

    /// Loads cached data (downloading it on first launch), then refreshes in the background when stale.
    func start() async {
        defer { hasStarted = true }
        currentSet = try? await catalog.index().latest
        lastUpdated = await catalog.lastUpdated()
        await loadCatalog(for: currentSet)
        if currentSet == nil || (lastUpdated.map { Date.now.timeIntervalSince($0) > autoRefreshInterval } ?? true) {
            await refresh(userInitiated: false)
        }
    }

    func refresh(userInitiated: Bool = true) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            currentSet = try await catalog.refresh().latest
            refreshError = nil
        } catch {
            // Keep cached data; only a manual refresh reports the failure.
            if userInitiated { refreshError = "Couldn't refresh data. Check your connection." }
            if currentSet == nil { currentSet = try? await catalog.index().latest }
        }
        lastUpdated = await catalog.lastUpdated()
        lookups.removeAll()
        traitLookups.removeAll()
        await loadCatalog(for: currentSet)
        await pins.compsChanged()
    }

    private func loadCatalog(for set: String?) async {
        guard let set, let loaded = try? await catalog.catalog(for: set) else { return }
        lookups[set] = loaded.championsByID
        traitLookups[set] = loaded.traitsByID
        catalogVersion += 1
    }

    /// Champions of `set` by ID; empty until the catalog is loaded.
    func champions(in set: String) -> [String: Champion] {
        _ = catalogVersion
        return lookups[set] ?? [:]
    }

    /// Traits of `set` by ID; empty until the catalog is loaded (or for catalogs without traits).
    func traits(in set: String) -> [String: Trait] {
        _ = catalogVersion
        return traitLookups[set] ?? [:]
    }

    /// Validates a code against the current set and resolves it.
    func resolve(_ code: TeamPlannerCode) async -> Result<Resolution, CompCodeError> {
        if currentSet == nil { currentSet = try? await catalog.index().latest }
        guard var latest = currentSet else { return .failure(.offline) }

        if TFTSet.relation(of: code.set, toLatest: latest) == .newer {
            // A new set may have been published since the last refresh.
            await refresh(userInitiated: false)
            latest = currentSet ?? latest
        }
        switch TFTSet.relation(of: code.set, toLatest: latest) {
        case .older: return .failure(.olderSet(code.set))
        case .newer: return .failure(.notAvailable(code.set))
        case .current: break
        }

        do {
            let resolution = try await catalog.resolve(code)
            if lookups[code.set] == nil { await loadCatalog(for: code.set) }
            return .success(resolution)
        } catch {
            return .failure(.offline)
        }
    }

    // MARK: Comps

    func comps() -> [Comp] {
        guard let currentSet else { return [] }
        return (try? repository.comps(in: currentSet)) ?? []
    }

    func add(name: String, rawCode: String, resolution: Resolution) throws -> Comp {
        let comp = try repository.add(
            name: Self.cleanName(name, fallback: defaultName(for: resolution)),
            set: resolution.set,
            rawCode: rawCode,
            championIDs: resolution.championIDs
        )
        Task { await pins.compsChanged() }
        return comp
    }

    /// Trait + carry name for a pasted code, made unique among the set's saved comps.
    func defaultName(for resolution: Resolution, excluding id: UUID? = nil) -> String {
        let base = Comp.defaultName(for: resolution.champions, traits: traits(in: resolution.set))
        let taken = Set(((try? repository.comps(in: resolution.set)) ?? []).filter { $0.id != id }.map(\.name))
        return Comp.uniqueName(base, taken: taken)
    }

    func rename(_ comp: Comp, to name: String) {
        comp.name = Self.cleanName(name, fallback: comp.name)
        try? repository.save()
        Task { await pins.compsChanged() }
    }

    func replaceCode(of comp: Comp, rawCode: String, resolution: Resolution) {
        comp.rawCode = TeamPlannerCode.normalized(rawCode)
        comp.set = resolution.set
        comp.championIDs = Array(resolution.championIDs.prefix(Comp.maxChampions))
        try? repository.save()
        Task { await pins.compsChanged() }
    }

    func delete(_ comp: Comp) async {
        try? repository.delete(comp)
        await pins.compsChanged()
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) async {
        guard let currentSet else { return }
        try? repository.move(in: currentSet, fromOffsets: source, toOffset: destination)
        await pins.compsChanged()
    }

    /// Settings → Clear comps: every set, and ends the Live Activity.
    func clearAll() async {
        try? repository.deleteAll()
        await pins.unpin()
    }

    /// Another saved comp with the same code, if any.
    func duplicate(of rawCode: String, excluding id: UUID? = nil) -> Comp? {
        guard let existing = try? repository.comp(rawCode: rawCode), existing.id != id else { return nil }
        return existing
    }

    // MARK: Pinning

    var pinnedCompID: UUID? { pins.pinnedCompID }

    func togglePin(_ comp: Comp) async {
        if pins.pinnedCompID == comp.id {
            await pins.unpin()
        } else {
            try? await pins.pin(comp)
        }
    }

    private static func cleanName(_ name: String, fallback: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}

extension AppModel {
    /// In-memory model with sample data and fake services.
    static func preview(withSamples: Bool = true, pinned: Bool = false) -> AppModel {
        let repository = CompRepository.preview(withSamples: withSamples)
        let first = (try? repository.comps(in: "TFTSet18"))?.first
        let model = AppModel(
            catalog: FakeCatalog(),
            repository: repository,
            pins: FakePinService(pinnedCompID: pinned ? first?.id : nil)
        )
        model.currentSet = SampleCatalog.index.latest
        model.lookups[SampleCatalog.set18.set] = SampleCatalog.set18.championsByID
        model.traitLookups[SampleCatalog.set18.set] = SampleCatalog.set18.traitsByID
        model.hasStarted = true
        return model
    }
}
