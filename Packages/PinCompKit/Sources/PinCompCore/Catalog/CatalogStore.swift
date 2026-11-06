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
        if let cached = cache.loadCatalog(set: set) {
            // Fills in missing island copies (e.g. caches written before they existed), offline when possible.
            let missing = cached.champions.filter { !cache.hasAllIcons(set: set, championID: $0.id) }
            if !missing.isEmpty { _ = await downloadIcons(missing, set: set, redownload: false) }
            return cached
        }
        // Missing icons show as placeholders and are retried on the next refresh.
        return try await downloadCatalog(set: set).catalog
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
        let (_, failedIcons) = try await downloadCatalog(set: index.latest)
        // Written last: its modification date is "last updated".
        try cache.write(indexData, to: cache.indexURL)
        if failedIcons > 0 { throw CatalogError.iconsIncomplete(missing: failedIcons) }
        return index
    }

    /// Downloads `champions.json`; fetches all icons when `generatedAt` changed, otherwise only missing ones.
    /// Returns the catalog and the number of icons that failed to download.
    private func downloadCatalog(set: String) async throws -> (catalog: SetCatalog, failedIcons: Int) {
        let data = try await fetch(baseURL.appending(path: set).appending(path: "champions.json"))
        let catalog = try JSONDecoder().decode(SetCatalog.self, from: data)
        let previous = cache.loadCatalog(set: set)
        let changed = previous?.generatedAt != catalog.generatedAt

        let needed = catalog.champions.filter { changed || !cache.hasAllIcons(set: set, championID: $0.id) }
        let failures = await downloadIcons(needed, set: set, redownload: changed)

        try cache.write(data, to: cache.catalogURL(set: set))
        return (catalog, failures)
    }

    /// Returns the number of icons that failed.
    /// Saves the full icon plus the island copies. Reuses a cached full icon unless `redownload`.
    private func downloadIcons(_ champions: [Champion], set: String, redownload: Bool) async -> Int {
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
                        let fullURL = cache.iconURL(set: set, championID: champion.id)
                        let png: Data
                        if !redownload, let cached = try? Data(contentsOf: fullURL) {
                            png = cached
                        } else {
                            png = try await fetch(champion.iconURL)
                            try cache.write(png, to: fullURL)
                        }
                        for size in IslandIconSize.allCases {
                            let small = try IconResizer.png(from: png, pixels: size.pixels)
                            try cache.write(small, to: cache.islandIconURL(set: set, championID: champion.id, size: size))
                        }
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
