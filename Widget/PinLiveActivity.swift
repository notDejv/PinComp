import ActivityKit
import PinCompActivity
import PinCompCore
import PinCompUI
import SwiftUI
import WidgetKit

@main
struct PinCompWidgetBundle: WidgetBundle {
    var body: some Widget {
        PinLiveActivity()
    }
}

struct PinLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PinAttributes.self) { context in
            PinLockScreenView(snapshot: PinSnapshot.load(context.state))
                .activityBackgroundTint(Surface.card)
                .activitySystemActionForegroundColor(.white)
                .widgetURL(PinLink.url(for: context.state.compID))
        } dynamicIsland: { context in
            let snapshot = PinSnapshot.load(context.state)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(snapshot.name)
                        .font(.headline)
                        .lineLimit(1)
                        .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(snapshot.positionText)
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    PinExpandedBody(snapshot: snapshot)
                }
            } compactLeading: {
                CompactIcon(champion: snapshot.featured(2).first, set: snapshot.set)
            } compactTrailing: {
                CompactIcon(champion: snapshot.featured(2).dropFirst().first, set: snapshot.set)
            } minimal: {
                CompactIcon(champion: snapshot.featured(1).first, set: snapshot.set)
            }
            .keylineTint(snapshot.featured(1).first.map { CostColor.color(for: $0.cost) })
            .widgetURL(PinLink.url(for: context.state.compID))
        }
    }
}

// MARK: Compact / minimal

private struct CompactIcon: View {
    let champion: Champion?
    let set: String

    var body: some View {
        if let champion {
            ChampionIcon(champion, set: set, size: 24, variant: .island(.compact))
        } else {
            Image(systemName: "pin.fill")
                .foregroundStyle(CostColor.color(for: 5))
        }
    }
}

// MARK: Expanded / Lock Screen

/// Board plus the Next / Unpin buttons; shared by the expanded island and the Lock Screen.
private struct PinExpandedBody: View {
    let snapshot: PinSnapshot
    @Environment(\.isDynamicIslandLimitedInWidth) private var limitedInWidth

    var body: some View {
        VStack(spacing: limitedInWidth ? 8 : 12) {
            board(snapshot)
                .frame(maxWidth: .infinity)
            PinButtons(canCycle: snapshot.canCycle, compact: limitedInWidth)
        }
    }

    @ViewBuilder private func board(_ snapshot: PinSnapshot) -> some View {
        if limitedInWidth {
            // Landscape: one row of the five highest-cost units.
            BoardView(slots: snapshot.featuredSlots(5), set: snapshot.set, style: .islandCompact)
        } else {
            BoardView(slots: snapshot.slots, set: snapshot.set, style: .island)
        }
    }
}

/// Large buttons: a tap anywhere else opens the app and pulls the user out of TFT.
private struct PinButtons: View {
    let canCycle: Bool
    let compact: Bool

    var body: some View {
        HStack(spacing: 10) {
            if canCycle {
                Button(intent: NextCompIntent()) {
                    Label("Next comp", systemImage: "forward.fill")
                        .frame(maxWidth: .infinity, minHeight: compact ? 36 : 44)
                }
                .tint(CostColor.color(for: 5))
                .foregroundStyle(.black)
            }
            Button(intent: UnpinIntent()) {
                Label("Unpin", systemImage: "pin.slash")
                    .frame(maxWidth: .infinity, minHeight: compact ? 36 : 44)
            }
            .tint(Surface.raised)
            .foregroundStyle(.white)
        }
        .font(.subheadline.weight(.semibold))
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
    }
}

private struct PinLockScreenView: View {
    let snapshot: PinSnapshot

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(snapshot.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(snapshot.positionText)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            PinExpandedBody(snapshot: snapshot)
        }
        .padding(16)
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
    }
}

// MARK: Previews

private extension PinAttributes.ContentState {
    static let one = PinSnapshot.previewState(position: 1, total: 1)
    static let several = PinSnapshot.previewState(position: 2, total: 5)
}

#Preview("Compact", as: .dynamicIsland(.compact), using: PinAttributes()) {
    PinLiveActivity()
} contentStates: {
    PinAttributes.ContentState.several
}

#Preview("Minimal", as: .dynamicIsland(.minimal), using: PinAttributes()) {
    PinLiveActivity()
} contentStates: {
    PinAttributes.ContentState.several
}

#Preview("Expanded", as: .dynamicIsland(.expanded), using: PinAttributes()) {
    PinLiveActivity()
} contentStates: {
    PinAttributes.ContentState.several
    PinAttributes.ContentState.one
}

#Preview("Lock Screen", as: .content, using: PinAttributes()) {
    PinLiveActivity()
} contentStates: {
    PinAttributes.ContentState.several
    PinAttributes.ContentState.one
}
