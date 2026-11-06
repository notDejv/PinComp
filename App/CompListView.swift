import PinCompCore
import PinCompUI
import SwiftData
import SwiftUI

struct CompListView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: [SortDescriptor(\Comp.sortIndex), SortDescriptor(\Comp.createdAt)]) private var allComps: [Comp]

    @State private var addRequest: AddRequest?
    @State private var showsSettings = false
    @State private var pinFeedback = 0

    /// Opens the add sheet, optionally with an already pasted code.
    struct AddRequest: Identifiable {
        let id = UUID()
        var pasted: String?
    }

    private var comps: [Comp] {
        guard let set = model.currentSet else { return [] }
        return allComps.filter { $0.set == set }
    }

    private var pinnedComp: Comp? {
        model.pinnedCompID.flatMap { id in comps.first { $0.id == id } }
    }

    var body: some View {
        Group {
            if comps.isEmpty {
                if model.hasStarted || model.currentSet != nil {
                    EmptyCompsView { addRequest = AddRequest(pasted: $0) }
                } else {
                    ProgressView()
                }
            } else {
                list
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Surface.background)
        .navigationTitle("Comps")
        .solidNavigationBar()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Settings", systemImage: "gearshape") { showsSettings = true }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add comp", systemImage: "plus") { addRequest = AddRequest() }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let pinnedComp {
                PinnedBar(comp: pinnedComp, canCycle: comps.count > 1) {
                    pinFeedback += 1
                    Task { await model.pins.next() }
                } unpin: {
                    pinFeedback += 1
                    Task { await model.pins.unpin() }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: pinnedComp?.id)
        .sensoryFeedback(.impact, trigger: pinFeedback)
        .sheet(item: $addRequest) { request in
            AddCompView(pasted: request.pasted)
        }
        .sheet(isPresented: $showsSettings) {
            SettingsView()
        }
    }

    private var list: some View {
        List {
            ForEach(comps) { comp in
                NavigationLink(value: comp.id) {
                    CompCard(
                        comp: comp,
                        champions: model.champions(in: comp.set),
                        isPinned: comp.id == model.pinnedCompID
                    ) {
                        pinFeedback += 1
                        Task { await model.togglePin(comp) }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
            .onMove { source, destination in
                Task { await model.move(fromOffsets: source, toOffset: destination) }
            }
            .onDelete { offsets in
                let doomed = offsets.map { comps[$0] }
                Task { for comp in doomed { await model.delete(comp) } }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

/// List card: name, mini board; the pinned card gets a cost-colored border.
struct CompCard: View {
    let comp: Comp
    let champions: [String: Champion]
    let isPinned: Bool
    let togglePin: () -> Void

    private var tint: Color {
        comp.featuredChampions(limit: 1, in: champions).first.map { CostColor.color(for: $0.cost) } ?? CostColor.unknown
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(comp.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Button(isPinned ? "Unpin" : "Pin", systemImage: isPinned ? "pin.fill" : "pin", action: togglePin)
                    .labelStyle(.iconOnly)
                    .font(.title3)
                    .foregroundStyle(isPinned ? tint : .secondary)
                    .buttonStyle(.plain)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            BoardView(slots: comp.slots(in: champions), set: comp.set, style: .card)
        }
        .padding(14)
        .background(
            LinearGradient(colors: [tint.opacity(0.14), Surface.card], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: .rect(cornerRadius: 16)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isPinned ? tint : .clear, lineWidth: 2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityValue(isPinned ? "Pinned" : "")
    }
}

/// Floating solid capsule: "Pinned: <name> · Next · Unpin".
struct PinnedBar: View {
    let comp: Comp
    let canCycle: Bool
    let next: () -> Void
    let unpin: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "pin.fill")
                .foregroundStyle(CostColor.color(for: 5))
            Text("Pinned: \(comp.name)")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 4)
            if canCycle {
                Button("Next", action: next)
                    .font(.subheadline.weight(.semibold))
            }
            Button("Unpin", action: unpin)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Surface.raised, in: .capsule)
        .overlay { Capsule().strokeBorder(Color.white.opacity(0.08)) }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

/// "No comps yet" with the two steps and a paste button so the first comp takes one tap.
struct EmptyCompsView: View {
    let onPaste: (String) -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "pin")
                .font(.system(size: 44))
                .foregroundStyle(CostColor.color(for: 5))
            Text("No comps yet")
                .font(.title2.bold())
            VStack(alignment: .leading, spacing: 10) {
                Text("1. Tap **Copy team code** on any comp guide")
                Text("2. Paste it here")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            PasteButton(payloadType: String.self) { strings in
                guard let first = strings.first else { return }
                Task { @MainActor in onPaste(first) }
            }
            .controlSize(.large)
            .buttonBorderShape(.capsule)
            .tint(CostColor.color(for: 5))
        }
        .padding(32)
    }
}

#Preview("List") {
    let model = AppModel.preview(pinned: true)
    return NavigationStack { CompListView() }
        .environment(model)
        .environment(FloatingCompController())
        .modelContainer(model.repository.container)
        .preferredColorScheme(.dark)
}

#Preview("Empty") {
    let model = AppModel.preview(withSamples: false)
    return NavigationStack { CompListView() }
        .environment(model)
        .environment(FloatingCompController())
        .modelContainer(model.repository.container)
        .preferredColorScheme(.dark)
}
