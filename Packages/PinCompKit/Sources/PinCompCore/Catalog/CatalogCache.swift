import Foundation

public enum AppGroup {
    public static let identifier = "group.com.dejvi.pincomp"

    /// The shared container, or Application Support when the entitlement is missing
    /// (unit tests, previews).
    public static var containerURL: URL {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) {
            return url
        }
        return URL.applicationSupportDirectory.appending(path: "PinCompGroup", directoryHint: .isDirectory)
    }
}

/// Synchronous, read-mostly access to the on-disk catalog under `Catalog/` in the App Group.
/// Used directly by the widget, which cannot download anything.
///
/// Layout: `Catalog/index.json`, `Catalog/<set>/champions.json`, `Catalog/<set>/icons/<id>.png`.
public struct CatalogCache: Sendable {
    public static let shared = CatalogCache(root: AppGroup.containerURL.appending(path: "Catalog", directoryHint: .isDirectory))

    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    public var indexURL: URL { root.appending(path: "index.json") }

    public func catalogURL(set: String) -> URL {
        root.appending(path: set, directoryHint: .isDirectory).appending(path: "champions.json")
    }

    public func iconsDirectory(set: String) -> URL {
        root.appending(path: set, directoryHint: .isDirectory).appending(path: "icons", directoryHint: .isDirectory)
    }

    public func iconURL(set: String, championID: String) -> URL {
        let safe = championID.replacingOccurrences(of: "/", with: "_")
        return iconsDirectory(set: set).appending(path: "\(safe).png")
    }

    /// Local icon file if it has been downloaded.
    public func cachedIcon(set: String, championID: String) -> URL? {
        let url = iconURL(set: set, championID: championID)
        return FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) ? url : nil
    }

    public func loadIndex() -> CatalogIndex? {
        load(CatalogIndex.self, from: indexURL)
    }

    public func loadCatalog(set: String) -> SetCatalog? {
        load(SetCatalog.self, from: catalogURL(set: set))
    }

    /// When the index was last downloaded successfully.
    public var lastUpdated: Date? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: indexURL.path(percentEncoded: false))
        return attributes?[.modificationDate] as? Date
    }

    func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    private func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
