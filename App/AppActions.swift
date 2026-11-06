import AppIntents
import PinCompActivity

/// App-level actions shared by the UI and intents.
@MainActor
enum AppActions {
    /// "Next comp": advances the Live Activity if a comp is pinned, and the floating window either way.
    static func nextComp() async {
        let model = AppModel.shared
        let floating = FloatingCompController.shared
        if model.pinnedCompID != nil {
            await model.pins.next()
            if let pinned = model.pinnedCompID { floating.follow(pinned) }
        } else {
            floating.next()
        }
    }
}

/// Siri / Shortcuts / Action button / Back Tap (via a shortcut).
struct PinCompShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NextCompIntent(),
            phrases: ["Next comp in \(.applicationName)", "\(.applicationName) next comp"],
            shortTitle: "Next comp",
            systemImageName: "forward.fill"
        )
    }
}
