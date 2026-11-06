import PinCompCore
import SwiftUI
import UIKit

extension EnvironmentValues {
    /// Where icons are read from. Widgets cannot fetch remote images, so everything loads from disk.
    @Entry public var catalogCache: CatalogCache = .shared
}

/// Decoded icons, keyed by file path. `NSCache` is thread-safe.
final class IconImageCache: @unchecked Sendable {
    static let shared = IconImageCache()
    private let cache = NSCache<NSString, UIImage>()

    /// Loads via `Data` → `UIImage(data:)`, which is more reliable in widget extensions than `contentsOfFile:`.
    func image(at url: URL) -> UIImage? {
        let key = url.path(percentEncoded: false) as NSString
        if let image = cache.object(forKey: key) { return image }
        guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}

/// A champion portrait with a cost-colored border.
/// Falls back to a cost-colored circle with initials, or `?` for unknown units.
public struct ChampionIcon: View {
    /// Which cached file to draw. The Live Activity must only use the small island copies.
    public enum Variant: Sendable, Equatable {
        case full
        case island(IslandIconSize)
    }

    let champion: Champion?
    let set: String
    let size: CGFloat
    let variant: Variant

    @Environment(\.catalogCache) private var cache

    public init(_ champion: Champion?, set: String, size: CGFloat, variant: Variant = .full) {
        self.champion = champion
        self.set = set
        self.size = size
        self.variant = variant
    }

    private var borderColor: Color {
        champion.map { CostColor.color(for: $0.cost) } ?? CostColor.unknown
    }

    private var border: CGFloat { max(1.5, size * 0.07) }
    private var corner: CGFloat { size * 0.22 }

    private var fileURL: URL? {
        guard let champion else { return nil }
        switch variant {
        case .full: return cache.cachedIcon(set: set, championID: champion.id)
        case .island(let islandSize): return cache.cachedIslandIcon(set: set, championID: champion.id, size: islandSize)
        }
    }

    public var body: some View {
        if let url = fileURL, let image = IconImageCache.shared.image(at: url) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(.rect(cornerRadius: corner))
                .overlay {
                    RoundedRectangle(cornerRadius: corner)
                        .strokeBorder(borderColor, lineWidth: border)
                }
                .accessibilityLabel(champion?.name ?? "Unknown champion")
        } else {
            ZStack {
                Circle().fill(borderColor)
                Text(champion.map { String($0.name.prefix(2)) } ?? "?")
                    .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.8))
                    .minimumScaleFactor(0.5)
            }
            .frame(width: size, height: size)
            .accessibilityLabel(champion?.name ?? "Unknown champion")
        }
    }
}
