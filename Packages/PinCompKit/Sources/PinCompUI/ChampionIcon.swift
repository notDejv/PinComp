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

    func image(at url: URL) -> UIImage? {
        let key = url.path(percentEncoded: false) as NSString
        if let image = cache.object(forKey: key) { return image }
        guard let image = UIImage(contentsOfFile: key as String) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}

/// A champion portrait with a cost-colored border. Falls back to initials, or `?` for unknown units.
public struct ChampionIcon: View {
    let champion: Champion?
    let set: String
    let size: CGFloat

    @Environment(\.catalogCache) private var cache

    public init(_ champion: Champion?, set: String, size: CGFloat) {
        self.champion = champion
        self.set = set
        self.size = size
    }

    private var borderColor: Color {
        champion.map { CostColor.color(for: $0.cost) } ?? CostColor.unknown
    }

    private var border: CGFloat { max(1.5, size * 0.07) }
    private var corner: CGFloat { size * 0.22 }

    public var body: some View {
        content
            .frame(width: size, height: size)
            .clipShape(.rect(cornerRadius: corner))
            .overlay {
                RoundedRectangle(cornerRadius: corner)
                    .strokeBorder(borderColor, lineWidth: border)
            }
            .accessibilityLabel(champion?.name ?? "Unknown champion")
    }

    @ViewBuilder private var content: some View {
        if let champion,
           let url = cache.cachedIcon(set: set, championID: champion.id),
           let image = IconImageCache.shared.image(at: url) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Surface.raised
                Text(champion.map { String($0.name.prefix(2)) } ?? "?")
                    .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
                    .foregroundStyle(borderColor)
            }
        }
    }
}
