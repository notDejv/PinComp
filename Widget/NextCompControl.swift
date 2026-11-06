import AppIntents
import PinCompActivity
import SwiftUI
import WidgetKit

/// Control Center button: next comp without leaving the game.
struct NextCompControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.dejvi.pincomp.next-comp") {
            ControlWidgetButton(action: NextCompIntent()) {
                Label("Next comp", systemImage: "forward.fill")
            }
        }
        .displayName("Next comp")
        .description("Shows the next saved comp in PinComp's floating window.")
    }
}
