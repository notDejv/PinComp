import PinCompCore
import PinCompUI
import SwiftUI

/// Floating window options, Next comp setup, Refresh data, Clear comps, About.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(FloatingCompController.self) private var floating
    @Environment(\.dismiss) private var dismiss
    @State private var confirmClear = false

    static let riotDisclaimer = """
        PinComp isn't endorsed by Riot Games and doesn't reflect the views or opinions of Riot Games \
        or anyone officially involved in producing or managing Riot Games properties. Riot Games and \
        all associated properties are trademarks or registered trademarks of Riot Games, Inc.
        """

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        Task { await model.refresh() }
                    } label: {
                        HStack {
                            Label("Refresh data", systemImage: "arrow.clockwise")
                            Spacer()
                            if model.isRefreshing { ProgressView() }
                        }
                    }
                    .disabled(model.isRefreshing)
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last updated \(Text.relativeTime(model.lastUpdated))")
                        if let set = model.currentSet {
                            Text("Current set: \(TFTSet.displayName(of: set))")
                        }
                        if let error = model.refreshError {
                            Text(error).foregroundStyle(.orange)
                        }
                    }
                }

                Section {
                    Picker("Layout", selection: Bindable(floating).layout) {
                        ForEach(FloatingCompController.Layout.allCases) { Text($0.title).tag($0) }
                    }
                    Toggle("Champion names", isOn: Bindable(floating).showsNames)
                    Toggle("Active traits", isOn: Bindable(floating).showsTraits)
                } header: {
                    Text("Floating window")
                } footer: {
                    Text("Changes apply to an open window right away.")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Back Tap", systemImage: "hand.tap")
                            .font(.subheadline.weight(.semibold))
                        Text("Double-tap the back of your iPhone for the next comp, triple-tap for the previous one. In the Shortcuts app, add PinComp's **Next comp** and **Previous comp** shortcuts, then pick them in Settings → Accessibility → Touch → Back Tap → Double Tap / Triple Tap.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Control Center", systemImage: "switch.2")
                            .font(.subheadline.weight(.semibold))
                        Text("Open Control Center, tap **+**, then **Add a Control** → PinComp → **Next comp** (and **Previous comp**).")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Siri & Action button", systemImage: "mic")
                            .font(.subheadline.weight(.semibold))
                        Text("Say \"PinComp next comp\", or assign the **Next comp** shortcut to the Action button.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Switch comps in game")
                }

                Section {
                    Button("Clear comps", systemImage: "trash", role: .destructive) { confirmClear = true }
                        .foregroundStyle(.red)
                } footer: {
                    Text("Deletes all saved comps from every set and unpins the Dynamic Island.")
                }

                Section("About") {
                    Text(Self.riotDisclaimer)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Champion data from Community Dragon.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Surface.card)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Surface.card, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Delete all comps?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear comps", role: .destructive) {
                    Task { await model.clearAll() }
                }
            } message: {
                Text("This can't be undone.")
            }
        }
        .presentationBackground(Surface.card)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    SettingsView()
        .environment(AppModel.preview())
        .environment(FloatingCompController())
}
