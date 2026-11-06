import PinCompActivity
import PinCompCore
import PinCompUI
import SwiftUI

@main
struct PinCompApp: App {
    @State private var model = AppModel.shared
    @State private var floating = FloatingCompController.shared

    init() {
        FloatingCompController.shared.attach(to: AppModel.shared)
        NextCompRouter.handler = { await AppActions.nextComp() }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(floating)
                .modelContainer(model.repository.container)
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(FloatingCompController.self) private var floating
    @Environment(\.scenePhase) private var scenePhase
    @State private var path: [UUID] = []

    var body: some View {
        NavigationStack(path: $path) {
            CompListView()
                .navigationDestination(for: UUID.self) { id in
                    CompDetailView(compID: id)
                }
        }
        .tint(CostColor.color(for: 5))
        .preferredColorScheme(.dark)
        .background(alignment: .bottomTrailing) {
            // PiP needs its layer in the window; it stays behind the content.
            FloatingSourceView(view: floating.sourceView)
                .frame(width: 2, height: 2)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .background(Surface.background)
        .task { await model.start() }
        .onChange(of: scenePhase) { _, phase in
            // Live Activities can end while the app is away (8-hour limit, Unpin on the island).
            if phase == .active {
                model.pins.refreshState()
                // The floating window is for use outside the app; coming back (e.g. tapping it) closes it.
                floating.stop()
            }
        }
        .onOpenURL { url in
            guard let id = PinLink.compID(from: url) else { return }
            path = [id]
        }
    }
}
