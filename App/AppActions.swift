import AppIntents
import PinCompActivity

/// App-level actions shared by the UI and intents.
@MainActor
enum AppActions {
    /// "Next comp" (offset 1) / "Previous comp" (offset -1): moves the Live Activity if a comp is pinned,
    /// and the floating window either way.
    static func cycleComp(by offset: Int) async {
        let model = AppModel.shared
        let floating = FloatingCompController.shared
        if model.pinnedCompID != nil {
            if offset < 0 { await model.pins.previous() } else { await model.pins.next() }
            if let pinned = model.pinnedCompID { floating.follow(pinned) }
        } else {
            floating.step(by: offset)
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
        AppShortcut(
            intent: PreviousCompIntent(),
            phrases: ["Previous comp in \(.applicationName)", "\(.applicationName) previous comp"],
            shortTitle: "Previous comp",
            systemImageName: "backward.fill"
        )
    }
}
