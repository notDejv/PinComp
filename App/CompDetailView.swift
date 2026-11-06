import PinCompCore
import PinCompUI
import SwiftData
import SwiftUI

struct CompDetailView: View {
    @Query private var matches: [Comp]

    init(compID: UUID) {
        _matches = Query(filter: #Predicate<Comp> { $0.id == compID })
    }

    var body: some View {
        if let comp = matches.first {
            CompDetailContent(comp: comp)
        } else {
            ContentUnavailableView("Comp not found", systemImage: "questionmark.square.dashed")
                .background(Surface.background)
        }
    }
}

private struct CompDetailContent: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let comp: Comp

    @State private var renaming = false
    @State private var draftName = ""
    @State private var replacing = false
    @State private var confirmDelete = false
    @State private var pinFeedback = 0

    private var isPinned: Bool { model.pinnedCompID == comp.id }
    private var champions: [String: Champion] { model.champions(in: comp.set) }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                BoardView(slots: comp.slots(in: champions), set: comp.set, style: .detail)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Surface.card, in: .rect(cornerRadius: 20))

                VStack(spacing: 12) {
                    Button(isPinned ? "Unpin" : "Pin to Dynamic Island", systemImage: isPinned ? "pin.slash" : "pin.fill") {
                        pinFeedback += 1
                        Task { await model.togglePin(comp) }
                    }
                    .buttonStyle(SolidButtonStyle(
                        fill: isPinned ? Surface.raised : CostColor.color(for: 5),
                        foreground: isPinned ? .primary : .black
                    ))

                    HStack(spacing: 12) {
                        Button("Rename", systemImage: "pencil") {
                            draftName = comp.name
                            renaming = true
                        }
                        Button("Replace code", systemImage: "doc.on.clipboard") { replacing = true }
                    }
                    .buttonStyle(SolidButtonStyle())

                    Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
                        .buttonStyle(SolidButtonStyle(foreground: .red))
                }
            }
            .padding(20)
        }
        .background(Surface.background)
        .navigationTitle(comp.name)
        .navigationBarTitleDisplayMode(.inline)
        .solidNavigationBar()
        .sensoryFeedback(.impact, trigger: pinFeedback)
        .alert("Rename comp", isPresented: $renaming) {
            TextField("Name", text: $draftName)
            Button("Cancel", role: .cancel) {}
            Button("Save") { model.rename(comp, to: draftName) }
        }
        .confirmationDialog("Delete \(comp.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    await model.delete(comp)
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $replacing) {
            ReplaceCodeView(comp: comp)
        }
    }
}

private struct ReplaceCodeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let comp: Comp
    @State private var add: AddCompModel

    init(comp: Comp) {
        self.comp = comp
        _add = State(initialValue: AddCompModel(replacing: comp.id))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    CodePasteArea(add: add)
                    if case .resolved(_, let resolution) = add.state {
                        BoardView(slots: resolution.compSlots, set: resolution.set, style: .detail)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(20)
                .animation(.spring(duration: 0.35), value: add.state)
            }
            .background(Surface.card)
            .navigationTitle("Replace code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Surface.card, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Replace") {
                        guard case .resolved(let rawCode, let resolution) = add.state else { return }
                        model.replaceCode(of: comp, rawCode: rawCode, resolution: resolution)
                        dismiss()
                    }
                    .disabled({ if case .resolved = add.state { false } else { true } }())
                }
            }
            .duplicateAlert(name: $add.duplicateName)
        }
        .presentationBackground(Surface.card)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    let model = AppModel.preview()
    let comp = model.comps().first!
    return NavigationStack { CompDetailView(compID: comp.id) }
        .environment(model)
        .modelContainer(model.repository.container)
        .preferredColorScheme(.dark)
}
