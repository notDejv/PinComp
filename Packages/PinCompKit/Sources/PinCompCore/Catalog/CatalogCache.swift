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
        existing(iconURL(set: set, championID: championID))
    }

    /// `Catalog/<set>/island/<id>@compact.png` and `@expanded.png`: small copies for the Live Activity,
    /// which may fail to start with images larger than their presentation size.
    public func islandIconURL(set: String, championID: String, size: IslandIconSize) -> URL {
        let safe = championID.replacingOccurrences(of: "/", with: "_")
        return root.appending(path: set, directoryHint: .isDirectory)
            .appending(path: "island", directoryHint: .isDirectory)
            .appending(path: "\(safe)@\(size.rawValue).png")
    }

    public func cachedIslandIcon(set: String, championID: String, size: IslandIconSize) -> URL? {
        existing(islandIconURL(set: set, championID: championID, size: size))
    }

    /// `Catalog/<set>/traits/<id>.png`: small white trait glyphs.
    public func traitIconURL(set: String, traitID: String) -> URL {
        let safe = traitID.replacingOccurrences(of: "/", with: "_")
        return root.appending(path: set, directoryHint: .isDirectory)
            .appending(path: "traits", directoryHint: .isDirectory)
            .appending(path: "\(safe).png")
    }

    public func cachedTraitIcon(set: String, traitID: String) -> URL? {
        existing(traitIconURL(set: set, traitID: traitID))
    }

    /// True when the full icon and both island copies are on disk.
    func hasAllIcons(set: String, championID: String) -> Bool {
        cachedIcon(set: set, championID: championID) != nil
            && IslandIconSize.allCases.allSatisfy { cachedIslandIcon(set: set, championID: championID, size: $0) != nil }
    }

    private func existing(_ url: URL) -> URL? {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) ? url : nil
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
