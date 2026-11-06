import PinCompCore
import SwiftUI

/// A comp's board, rendered identically in the list card, the detail screen and the Dynamic Island.
public struct BoardView: View {
    public struct Style: Sendable, Equatable {
        public var iconSize: CGFloat
        public var spacing: CGFloat
        public var columns: Int
        public var showsNames: Bool

        public init(iconSize: CGFloat, spacing: CGFloat, columns: Int = 5, showsNames: Bool = false) {
            self.iconSize = iconSize
            self.spacing = spacing
            self.columns = columns
            self.showsNames = showsNames
        }

        public static let card = Style(iconSize: 30, spacing: 5)
        public static let detail = Style(iconSize: 56, spacing: 10, showsNames: true)
        public static let island = Style(iconSize: 34, spacing: 6)
        /// Landscape island (`isDynamicIslandLimitedInWidth`).
        public static let islandCompact = Style(iconSize: 26, spacing: 4)
    }

    let slots: [CompSlot]
    let set: String
    let style: Style

    public init(slots: [CompSlot], set: String, style: Style) {
        self.slots = slots
        self.set = set
        self.style = style
    }

    private var rows: [[CompSlot]] {
        let columns = max(style.columns, 1)
        return stride(from: 0, to: slots.count, by: columns).map {
            Array(slots[$0..<min($0 + columns, slots.count)])
        }
    }

    public var body: some View {
        Grid(alignment: .leading, horizontalSpacing: style.spacing, verticalSpacing: style.spacing) {
            ForEach(rows.indices, id: \.self) { row in
                GridRow {
                    ForEach(rows[row]) { slot in
                        cell(slot)
                    }
                }
            }
        }
    }

    @ViewBuilder private func cell(_ slot: CompSlot) -> some View {
        if style.showsNames {
            VStack(spacing: 4) {
                ChampionIcon(slot.champion, set: set, size: style.iconSize)
                Text(slot.champion?.name ?? "?")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: style.iconSize + style.spacing)
            }
        } else {
            ChampionIcon(slot.champion, set: set, size: style.iconSize)
        }
    }
}

#Preview("Board styles") {
    let code = try! TeamPlannerCode(parsing: SampleCatalog.userCode)
    let slots = Resolution(code: code, catalog: SampleCatalog.set18).compSlots
    return VStack(alignment: .leading, spacing: 24) {
        BoardView(slots: slots, set: code.set, style: .card)
        BoardView(slots: slots, set: code.set, style: .detail)
        BoardView(slots: slots, set: code.set, style: .island)
    }
    .padding()
    .background(Surface.background)
    .preferredColorScheme(.dark)
}
