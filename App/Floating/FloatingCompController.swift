import AVFoundation
import AVKit
import Observation
import PinCompCore
import SwiftData
import SwiftUI

/// Experimental: floats the board over full-screen apps (TFT hides the Dynamic Island) using
/// the video-call flavor of Picture in Picture, which has no playback controls and shows a live view.
///
/// Floating is independent of the Live Activity pin. While both are on, the Live Activity's
/// "Next comp" (Notification Center, Watch, Lock Screen) also changes the floating board.
@MainActor
@Observable
final class FloatingCompController {
    /// The window's natural size; the user can resize it and the content scales.
    static let contentSize = CGSize(width: 320, height: 210)

    private(set) var isActive = false
    private(set) var floatingCompID: UUID?
    private(set) var errorMessage: String?

    /// The in-app view the window animates from. Must be in the window hierarchy.
    let sourceView = UIView()

    @ObservationIgnored private var pipController: AVPictureInPictureController?
    @ObservationIgnored private var stateDelegate: StateDelegate?
    @ObservationIgnored private var possibleObservation: NSKeyValueObservation?
    @ObservationIgnored private var startWhenPossible = false
    @ObservationIgnored private weak var model: AppModel?

    var isSupported: Bool { AVPictureInPictureController.isPictureInPictureSupported() }

    func attach(to model: AppModel) {
        self.model = model
    }

    /// Starts the floating window with `comp`, or switches the open window to it.
    func float(_ comp: Comp) async {
        errorMessage = nil
        guard isSupported else {
            errorMessage = "Picture in Picture isn't supported on this device."
            return
        }
        guard let model else { return }
        floatingCompID = comp.id
        if isActive { return }
        activateAudioSession()
        guard let controller = makeControllerIfNeeded(model: model) else { return }
        if controller.isPictureInPicturePossible {
            controller.startPictureInPicture()
        } else {
            startWhenPossible = true
        }
    }

    /// Follows the pinned comp when it changes (e.g. "Next comp" from Notification Center).
    func follow(_ compID: UUID) {
        if isActive { floatingCompID = compID }
    }

    func stop() {
        startWhenPossible = false
        pipController?.stopPictureInPicture()
    }

    // MARK: PiP plumbing

    private func makeControllerIfNeeded(model: AppModel) -> AVPictureInPictureController? {
        if let pipController { return pipController }

        let callController = AVPictureInPictureVideoCallViewController()
        callController.preferredContentSize = Self.contentSize
        let hosting = UIHostingController(
            rootView: FloatingBoardView()
                .environment(model)
                .environment(self)
                .modelContainer(model.repository.container)
        )
        hosting.view.backgroundColor = .clear
        callController.addChild(hosting)
        hosting.view.frame = callController.view.bounds
        hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        callController.view.addSubview(hosting.view)
        hosting.didMove(toParent: callController)

        let source = AVPictureInPictureController.ContentSource(
            activeVideoCallSourceView: sourceView,
            contentViewController: callController
        )
        let controller = AVPictureInPictureController(contentSource: source)
        // Only the Float button starts it; otherwise it would pop up every time the app is left.
        controller.canStartPictureInPictureAutomaticallyFromInline = false

        let state = StateDelegate(
            onChange: { [weak self] active in self?.isActive = active },
            onFailure: { [weak self] in
                self?.isActive = false
                self?.errorMessage = "Couldn't start the floating window."
            }
        )
        controller.delegate = state
        possibleObservation = controller.observe(\.isPictureInPicturePossible, options: [.new]) { [weak self] controller, _ in
            let possible = controller.isPictureInPicturePossible
            Task { @MainActor in
                guard let self, possible, self.startWhenPossible else { return }
                self.startWhenPossible = false
                self.pipController?.startPictureInPicture()
            }
        }
        pipController = controller
        stateDelegate = state
        return controller
    }

    /// PiP requires an active playback audio session; mixing keeps the game's audio playing.
    private func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }
}

private final class StateDelegate: NSObject, AVPictureInPictureControllerDelegate, Sendable {
    let onChange: @MainActor @Sendable (Bool) -> Void
    let onFailure: @MainActor @Sendable () -> Void

    init(onChange: @escaping @MainActor @Sendable (Bool) -> Void, onFailure: @escaping @MainActor @Sendable () -> Void) {
        self.onChange = onChange
        self.onFailure = onFailure
    }

    func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
        let onChange = onChange
        Task { @MainActor in onChange(true) }
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        let onChange = onChange
        Task { @MainActor in onChange(false) }
    }

    /// Tapping the window returns to the app; the app then closes the window (see `RootView`).
    func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(true)
    }

    func pictureInPictureController(_ controller: AVPictureInPictureController, failedToStartPictureInPictureWithError error: any Error) {
        let onFailure = onFailure
        Task { @MainActor in onFailure() }
    }
}

/// Hosts `sourceView` in the app's window. It stays tiny and behind the content.
struct FloatingSourceView: UIViewRepresentable {
    let view: UIView

    func makeUIView(context: Context) -> UIView { view }
    func updateUIView(_ view: UIView, context: Context) {}
}
