import Foundation

public protocol CatalogProviding: Sendable {
    /// Cached index, downloading it if none is cached yet.
    func index() async throws -> CatalogIndex
    /// Cached set catalog (with icons), downloading it if none is cached yet.
    func catalog(for set: String) async throws -> SetCatalog
    /// Re-downloads the index, the latest set's catalog and, when it changed, its icons.
    @discardableResult func refresh() async throws -> CatalogIndex
    func lastUpdated() async -> Date?
}

extension CatalogProviding {
    public func resolve(_ code: TeamPlannerCode) async throws -> Resolution {
        Resolution(code: code, catalog: try await catalog(for: code.set))
    }
}

public enum CatalogError: Error, Equatable, Sendable {
    case badResponse(URL, status: Int)
    /// Some icons could not be downloaded; they are retried on the next refresh.
    case iconsIncomplete(missing: Int)
}

/// Downloads catalog JSON and icon PNGs from GitHub Pages into the App Group.
public actor CatalogStore: CatalogProviding {
    public typealias Fetch = @Sendable (URL) async throws -> Data

    public static let defaultBaseURL = URL(string: "https://notdejv.github.io/PinComp/")!
    public static let shared = CatalogStore()

    public nonisolated let cache: CatalogCache
    private let baseURL: URL
    private let fetch: Fetch
    private var refreshTask: Task<CatalogIndex, Error>?

    public init(
        baseURL: URL = CatalogStore.defaultBaseURL,
        cache: CatalogCache = .shared,
        fetch: @escaping Fetch = CatalogStore.urlSessionFetch
    ) {
        self.baseURL = baseURL
        self.cache = cache
        self.fetch = fetch
    }

    public static let urlSessionFetch: Fetch = { url in
        let (data, response) = try await URLSession.shared.data(from: url)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw CatalogError.badResponse(url, status: status) }
        return data
    }

    public func index() async throws -> CatalogIndex {
        if let cached = cache.loadIndex() { return cached }
        return try await refresh()
    }

    public func catalog(for set: String) async throws -> SetCatalog {
        if let cached = cache.loadCatalog(set: set) { return cached }
        return try await downloadCatalog(set: set)
    }

    public func lastUpdated() -> Date? {
        cache.lastUpdated
    }

    @discardableResult
    public func refresh() async throws -> CatalogIndex {
        if let refreshTask { return try await refreshTask.value }
        let task = Task { try await performRefresh() }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    private func performRefresh() async throws -> CatalogIndex {
        let indexData = try await fetch(baseURL.appending(path: "index.json"))
        let index = try JSONDecoder().decode(CatalogIndex.self, from: indexData)
        _ = try await downloadCatalog(set: index.latest)
        // Written last: its modification date is "last updated".
        try cache.write(indexData, to: cache.indexURL)
        return index
    }

    /// Downloads `champions.json`; fetches all icons when `generatedAt` changed, otherwise only missing ones.
    private func downloadCatalog(set: String) async throws -> SetCatalog {
        let data = try await fetch(baseURL.appending(path: set).appending(path: "champions.json"))
        let catalog = try JSONDecoder().decode(SetCatalog.self, from: data)
        let previous = cache.loadCatalog(set: set)
        let changed = previous?.generatedAt != catalog.generatedAt

        let needed = catalog.champions.filter { changed || cache.cachedIcon(set: set, championID: $0.id) == nil }
        let failures = await downloadIcons(needed, set: set)

        try cache.write(data, to: cache.catalogURL(set: set))
        if failures > 0 { throw CatalogError.iconsIncomplete(missing: failures) }
        return catalog
    }

    /// Returns the number of icons that failed.
    private func downloadIcons(_ champions: [Champion], set: String) async -> Int {
        let fetch = fetch
        let cache = cache
        let maxConcurrent = 6
        return await withTaskGroup(of: Bool.self) { group in
            var failures = 0
            var pending = champions[...]
            func enqueue() {
                guard let champion = pending.popFirst() else { return }
                group.addTask {
                    do {
                        let png = try await fetch(champion.iconURL)
                        try cache.write(png, to: cache.iconURL(set: set, championID: champion.id))
                        return true
                    } catch {
                        return false
                    }
                }
            }
            for _ in 0..<maxConcurrent { enqueue() }
            for await ok in group {
                if !ok { failures += 1 }
                enqueue()
            }
            return failures
        }
    }
}
