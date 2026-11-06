import PinCompCore
import SwiftUI

/// Compact active-trait badge: glyph + unit count on a tier-colored capsule.
public struct TraitChip: View {
    let active: ActiveTrait
    let set: String
    let height: CGFloat

    @Environment(\.catalogCache) private var cache

    public init(_ active: ActiveTrait, set: String, height: CGFloat = 20) {
        self.active = active
        self.set = set
        self.height = height
    }

    /// Bronze, silver, gold, then prismatic for the 4th breakpoint and up.
    public static func color(tier: Int) -> Color {
        switch tier {
        case ...1: Color(red: 0.69, green: 0.48, blue: 0.29)
        case 2: Color(red: 0.66, green: 0.70, blue: 0.74)
        case 3: Color(red: 0.91, green: 0.72, blue: 0.29)
        default: Color(red: 0.44, green: 0.89, blue: 0.88)
        }
    }

    public var body: some View {
        HStack(spacing: 3) {
            if let url = cache.cachedTraitIcon(set: set, traitID: active.trait.id),
               let image = IconImageCache.shared.image(at: url) {
                Image(uiImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: height * 0.7, height: height * 0.7)
            } else {
                Text(String(active.trait.name.prefix(3)))
                    .font(.system(size: height * 0.45, weight: .bold))
            }
            Text("\(active.count)")
                .font(.system(size: height * 0.6, weight: .bold).monospacedDigit())
        }
        .foregroundStyle(.black.opacity(0.85))
        .padding(.horizontal, height * 0.3)
        .frame(height: height)
        .background(Self.color(tier: active.tier), in: .capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(active.trait.name) \(active.count)")
    }
}
