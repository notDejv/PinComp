import AVFoundation
import AVKit
import Observation
import PinCompCore
import PinCompUI
import SwiftUI

/// Experimental: floats the board over full-screen apps (TFT hides the Dynamic Island) using
/// Picture in Picture with a still frame rendered into an `AVSampleBufferDisplayLayer`.
///
/// The PiP skip-forward button shows the next current-set comp; skip-back shows the previous one.
@MainActor
@Observable
final class FloatingCompController {
    private(set) var isActive = false
    private(set) var floatingCompID: UUID?
    private(set) var errorMessage: String?

    let displayLayer = AVSampleBufferDisplayLayer()

    @ObservationIgnored private var pipController: AVPictureInPictureController?
    @ObservationIgnored private var playbackDelegate: PlaybackDelegate?
    @ObservationIgnored private var stateDelegate: StateDelegate?
    @ObservationIgnored private var possibleObservation: NSKeyValueObservation?
    @ObservationIgnored private var startWhenPossible = false
    @ObservationIgnored private weak var model: AppModel?

    var isSupported: Bool { AVPictureInPictureController.isPictureInPictureSupported() }

    init() {
        displayLayer.videoGravity = .resizeAspect
    }

    func attach(to model: AppModel) {
        self.model = model
    }

    /// Renders `comp`, then starts PiP. If the user leaves the app instead, PiP starts automatically.
    func float(_ comp: Comp) {
        errorMessage = nil
        guard isSupported else {
            errorMessage = "Picture in Picture isn't supported on this device."
            return
        }
        activateAudioSession()
        show(comp)
        let controller = makeControllerIfNeeded()
        if controller.isPictureInPicturePossible {
            controller.startPictureInPicture()
        } else {
            startWhenPossible = true
        }
    }

    func stop() {
        pipController?.stopPictureInPicture()
    }

    /// Re-renders the floating comp, e.g. after a rename or a catalog refresh.
    func refresh() {
        guard let id = floatingCompID, let comp = model?.comps().first(where: { $0.id == id }) else { return }
        show(comp)
    }

    // MARK: Frames

    private func show(_ comp: Comp) {
        guard let model else { return }
        let comps = model.comps()
        let index = comps.firstIndex { $0.id == comp.id }
        let frame = FloatingBoardFrame(
            name: comp.name,
            position: index.map { "\($0 + 1)/\(comps.count)" } ?? "",
            set: comp.set,
            slots: comp.slots(in: model.champions(in: comp.set))
        )
        guard let buffer = FloatingFrameRenderer.sampleBuffer(for: frame) else {
            errorMessage = "Couldn't draw the floating board."
            return
        }
        displayLayer.sampleBufferRenderer.flush()
        displayLayer.sampleBufferRenderer.enqueue(buffer)
        floatingCompID = comp.id
    }

    private func step(forward: Bool) {
        guard let model, let id = floatingCompID else { return }
        let comps = model.comps()
        guard !comps.isEmpty else { return }
        let current = comps.firstIndex { $0.id == id } ?? 0
        let next = (current + (forward ? 1 : -1) + comps.count) % comps.count
        show(comps[next])
    }

    // MARK: PiP plumbing

    private func makeControllerIfNeeded() -> AVPictureInPictureController {
        if let pipController { return pipController }
        let playback = PlaybackDelegate { [weak self] forward in self?.step(forward: forward) }
        let source = AVPictureInPictureController.ContentSource(
            sampleBufferDisplayLayer: displayLayer,
            playbackDelegate: playback
        )
        let controller = AVPictureInPictureController(contentSource: source)
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.requiresLinearPlayback = false
        let state = StateDelegate { [weak self] active in
            self?.isActive = active
            // Re-enqueue so the window never shows an empty frame after a transition.
            if active { self?.refresh() }
        }
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
        playbackDelegate = playback
        stateDelegate = state
        return controller
    }

    /// PiP requires an active playback audio session; mixing keeps the game's audio playing.
    private func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
        try? session.setActive(true)
    }
}

/// "Live", endless timeline: no scrubber, skip buttons cycle comps.
private final class PlaybackDelegate: NSObject, AVPictureInPictureSampleBufferPlaybackDelegate, Sendable {
    let onSkip: @MainActor @Sendable (Bool) -> Void

    init(onSkip: @escaping @MainActor @Sendable (Bool) -> Void) {
        self.onSkip = onSkip
    }

    func pictureInPictureController(_ controller: AVPictureInPictureController, setPlaying playing: Bool) {}

    func pictureInPictureControllerTimeRangeForPlayback(_ controller: AVPictureInPictureController) -> CMTimeRange {
        CMTimeRange(start: .negativeInfinity, duration: .positiveInfinity)
    }

    func pictureInPictureControllerIsPlaybackPaused(_ controller: AVPictureInPictureController) -> Bool {
        false
    }

    func pictureInPictureController(_ controller: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {}

    func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        skipByInterval skipInterval: CMTime,
        completion completionHandler: @escaping () -> Void
    ) {
        let forward = skipInterval.seconds >= 0
        let onSkip = onSkip
        Task { @MainActor in onSkip(forward) }
        completionHandler()
    }
}

private final class StateDelegate: NSObject, AVPictureInPictureControllerDelegate, Sendable {
    let onChange: @MainActor @Sendable (Bool) -> Void

    init(onChange: @escaping @MainActor @Sendable (Bool) -> Void) {
        self.onChange = onChange
    }

    func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
        let onChange = onChange
        Task { @MainActor in onChange(true) }
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        let onChange = onChange
        Task { @MainActor in onChange(false) }
    }
}

/// Hosts the display layer. PiP needs the layer in a visible window to start, so this doubles as the preview.
struct FloatingLayerView: UIViewRepresentable {
    let layer: AVSampleBufferDisplayLayer

    func makeUIView(context: Context) -> LayerHostView {
        let view = LayerHostView()
        view.hostedLayer = layer
        return view
    }

    func updateUIView(_ view: LayerHostView, context: Context) {}

    final class LayerHostView: UIView {
        var hostedLayer: CALayer? {
            didSet {
                oldValue?.removeFromSuperlayer()
                if let hostedLayer { layer.addSublayer(hostedLayer) }
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            hostedLayer?.frame = bounds
        }
    }
}
