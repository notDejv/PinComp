import PinCompCore
import PinCompUI
import SwiftUI

/// Paste → parse → resolve → preview. Also used to replace an existing comp's code.
@MainActor
@Observable
final class AddCompModel {
    enum State: Equatable {
        case idle
        case loading
        case resolved(rawCode: String, resolution: Resolution)
        case failed(String)
    }

    private(set) var state: State = .idle
    var name = ""
    /// Set when the pasted code is already saved; drives the duplicate alert.
    var duplicateName: String?
    private(set) var pasteCount = 0

    /// The comp whose code is being replaced; it doesn't count as a duplicate of itself.
    private let replacing: UUID?

    init(replacing: UUID? = nil) {
        self.replacing = replacing
    }

    func handlePaste(_ raw: String, model: AppModel) async {
        let code: TeamPlannerCode
        do {
            code = try TeamPlannerCode(parsing: raw)
        } catch {
            state = .failed(CompCodeError.notACode.localizedDescription)
            return
        }
        if let existing = model.duplicate(of: raw, excluding: replacing) {
            duplicateName = existing.name
            return
        }

        state = .loading
        switch await model.resolve(code) {
        case .success(let resolution):
            if name.isEmpty || replacing == nil { name = Comp.defaultName(for: resolution.champions) }
            state = .resolved(rawCode: TeamPlannerCode.normalized(raw), resolution: resolution)
            pasteCount += 1
        case .failure(let error):
            state = .failed(error.localizedDescription)
        }
    }
}

struct AddCompView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var add = AddCompModel()
    @State private var saveError: String?

    /// A code pasted from the empty state before the sheet opened.
    let pasted: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    CodePasteArea(add: add)
                    if case .resolved(_, let resolution) = add.state {
                        ResolvedPreview(resolution: resolution, name: $add.name)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    if let saveError {
                        Text(saveError).foregroundStyle(.red).font(.callout)
                    }
                }
                .padding(20)
                .animation(.spring(duration: 0.35), value: add.state)
            }
            .background(Surface.card)
            .navigationTitle("Add comp")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Surface.card, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!isResolved)
                }
            }
            .duplicateAlert(name: $add.duplicateName)
        }
        .presentationBackground(Surface.card)
        .preferredColorScheme(.dark)
        .task {
            if let pasted { await add.handlePaste(pasted, model: model) }
        }
    }

    private var isResolved: Bool {
        if case .resolved = add.state { true } else { false }
    }

    private func save() {
        guard case .resolved(let rawCode, let resolution) = add.state else { return }
        // Re-check: another sheet or device may have saved it meanwhile.
        if let existing = model.duplicate(of: rawCode) {
            add.duplicateName = existing.name
            return
        }
        do {
            _ = try model.add(name: add.name, rawCode: rawCode, resolution: resolution)
            dismiss()
        } catch {
            saveError = "Couldn't save the comp."
        }
    }
}

/// The large centered paste button plus loading / error feedback.
struct CodePasteArea: View {
    @Environment(AppModel.self) private var model
    let add: AddCompModel

    var body: some View {
        VStack(spacing: 14) {
            PasteButton(payloadType: String.self) { strings in
                guard let first = strings.first else { return }
                Task { @MainActor in await add.handlePaste(first, model: model) }
            }
            .controlSize(.extraLarge)
            .buttonBorderShape(.capsule)
            .tint(CostColor.color(for: 5))
            .padding(.top, 12)

            switch add.state {
            case .idle:
                Text("Copy a team code from TFT Academy, MetaTFT or the in-game planner.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            case .loading:
                ProgressView()
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            case .resolved:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
        .sensoryFeedback(.success, trigger: add.pasteCount)
    }
}

struct ResolvedPreview: View {
    let resolution: Resolution
    @Binding var name: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            BoardView(slots: resolution.compSlots, set: resolution.set, style: .detail)
                .frame(maxWidth: .infinity)
            if !resolution.unknown.isEmpty {
                Text("\(resolution.unknown.count) unit(s) aren't in the champion data yet and show as ?.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Name").font(.caption).foregroundStyle(.secondary)
                TextField("Comp name", text: $name)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .padding(12)
                    .background(Surface.raised, in: .rect(cornerRadius: 12))
            }
        }
    }
}

extension View {
    /// "You already saved this comp as <name>." with a single OK.
    func duplicateAlert(name: Binding<String?>) -> some View {
        alert(
            "You already saved this comp as \(name.wrappedValue ?? "")." ,
            isPresented: Binding(get: { name.wrappedValue != nil }, set: { if !$0 { name.wrappedValue = nil } })
        ) {
            Button("OK", role: .cancel) {}
        }
    }
}

#Preview {
    let model = AppModel.preview()
    return Color.black.sheet(isPresented: .constant(true)) {
        AddCompView(pasted: SampleCatalog.userCode)
    }
    .environment(model)
}
