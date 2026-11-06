import PinCompCore
import PinCompUI
import SwiftData
import SwiftUI

/// Live content of the floating window. Shows the pinned comp, so "Next comp" in Notification Center
/// (or the Live Activity on the Watch / Lock Screen) also changes what's floating.
struct FloatingBoardView: View {
    @Environment(AppModel.self) private var model
    @Environment(FloatingCompController.self) private var floating
    @Query(sort: [SortDescriptor(\Comp.sortIndex), SortDescriptor(\Comp.createdAt)]) private var allComps: [Comp]

    private var comps: [Comp] {
        guard let set = model.currentSet else { return [] }
        return allComps.filter { $0.set == set }
    }

    private var shownID: UUID? { model.pinnedCompID ?? floating.floatingCompID }

    var body: some View {
        Group {
            if let id = shownID, let index = comps.firstIndex(where: { $0.id == id }) {
                board(comps[index], position: "\(index + 1)/\(comps.count)")
            } else {
                Text("No comp pinned")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Surface.background)
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .onChange(of: model.pinnedCompID) { _, pinned in
            // Unpin (Notification Center, Watch, Lock Screen or the app) also closes the window.
            if pinned == nil { floating.stop() }
        }
    }

    /// Laid out at the window's natural size, then scaled to whatever size the user resizes it to.
    private func board(_ comp: Comp, position: String) -> some View {
        content(comp, position: position)
            .scaleToFit(FloatingCompController.contentSize)
    }

    private func content(_ comp: Comp, position: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(comp.name)
                    .font(.system(size: 20, weight: .bold))
                    .lineLimit(1)
                Spacer()
                Text(position)
                    .font(.system(size: 18, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            BoardView(slots: comp.slots(in: model.champions(in: comp.set)), set: comp.set, style: .floating)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

extension BoardView.Style {
    /// Five 46 pt icons with names per row fit the 320 × 210 pt window.
    static let floating = BoardView.Style(iconSize: 46, spacing: 6, showsNames: true)
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
