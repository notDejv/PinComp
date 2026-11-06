import PinCompCore
import PinCompUI
import SwiftData
import SwiftUI

/// Live content of the floating window. Follows the Live Activity's "Next comp" while a comp is pinned.
struct FloatingBoardView: View {
    @Environment(AppModel.self) private var model
    @Environment(FloatingCompController.self) private var floating
    @Query(sort: [SortDescriptor(\Comp.sortIndex), SortDescriptor(\Comp.createdAt)]) private var allComps: [Comp]

    private var comps: [Comp] {
        guard let set = model.currentSet else { return [] }
        return allComps.filter { $0.set == set }
    }

    var body: some View {
        Group {
            if let id = floating.floatingCompID, let index = comps.firstIndex(where: { $0.id == id }) {
                content(comps[index], position: "\(index + 1)/\(comps.count)")
                    .scaleToFit(floating.contentSize)
            } else {
                Text("Comp not found")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Surface.background)
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .onChange(of: model.pinnedCompID) { _, pinned in
            if let pinned { floating.follow(pinned) }
        }
    }

    /// Laid out at the window's natural size (`contentSize`), then scaled to the window.
    private func content(_ comp: Comp, position: String) -> some View {
        let all = comp.slots(in: model.champions(in: comp.set))
        let slots = floating.layout == .top5 ? Self.top5(all) : all
        let traits = ActiveTrait.compute(slots: all, traits: model.traits(in: comp.set))

        return VStack(alignment: .leading, spacing: FloatingCompController.sectionSpacing) {
            HStack {
                Text(comp.name)
                    .font(.system(size: 20, weight: .bold))
                    .lineLimit(1)
                Spacer()
                Text(position)
                    .font(.system(size: 18, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .frame(height: FloatingCompController.headerHeight)

            if floating.showsTraits {
                TraitRow(traits: traits, set: comp.set)
            }

            BoardView(slots: slots, set: comp.set, style: floating.boardStyle)
        }
        .padding(FloatingCompController.padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// The five highest-cost units as board slots (traits are still computed from the full board).
    private static func top5(_ slots: [CompSlot]) -> [CompSlot] {
        Comp.featured(slots, limit: 5).enumerated().map {
            CompSlot(index: $0.offset, championID: $0.element.id, champion: $0.element)
        }
    }
}

/// As many active traits as fit on one line, strongest first.
private struct TraitRow: View {
    let traits: [ActiveTrait]
    let set: String

    var body: some View {
        HStack(spacing: 4) {
            if traits.isEmpty {
                Text("No active traits")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(traits.prefix(7)) { active in
                    TraitChip(active, set: set, height: FloatingCompController.traitHeight)
                }
            }
        }
        .frame(height: FloatingCompController.traitHeight, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
    }
}

private extension View {
    /// Scales a fixed-size layout uniformly to fill the available space.
    func scaleToFit(_ natural: CGSize) -> some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / natural.width, proxy.size.height / natural.height)
            self
                .frame(width: natural.width, height: natural.height)
                .scaleEffect(scale)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}
