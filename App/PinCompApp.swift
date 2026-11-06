import PinCompActivity
import PinCompCore
import PinCompUI
import SwiftUI

@main
struct PinCompApp: App {
    @State private var model = AppModel.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .modelContainer(model.repository.container)
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
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
        .background(Surface.background)
        .task { await model.start() }
        .onChange(of: scenePhase) { _, phase in
            // Live Activities can end while the app is away (8-hour limit, Unpin on the island).
            if phase == .active { model.pins.refreshState() }
        }
        .onOpenURL { url in
            guard let id = PinLink.compID(from: url) else { return }
            path = [id]
        }
    }
}
