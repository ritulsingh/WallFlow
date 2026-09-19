import AppKit
import AVFoundation

@MainActor
final class VideoLoopController {
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var playerLayer: AVPlayerLayer?
    private var statusObserver: NSKeyValueObservation?
    private weak var container: NSView?
    private var wantsPlayback = false

    func attach(to view: NSView) {
        container = view
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor

        let layer = AVPlayerLayer()
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        view.layer?.addSublayer(layer)
        playerLayer = layer
        layout()
    }

    func load(url: URL, muted: Bool, fill: Bool, maximumResolution: CGSize? = nil) {
        statusObserver = nil
        looper = nil
        player?.pause()
        player = nil

        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 0
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = false
        if let maximumResolution, maximumResolution.width > 0, maximumResolution.height > 0 {
            item.preferredMaximumResolution = maximumResolution
        }

        let queue = AVQueuePlayer()
        queue.isMuted = muted
        queue.volume = muted ? 0 : 1
        queue.automaticallyWaitsToMinimizeStalling = false
        queue.allowsExternalPlayback = false
        queue.preventsDisplaySleepDuringVideoPlayback = false
        queue.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible

        looper = AVPlayerLooper(player: queue, templateItem: item)
        player = queue
        playerLayer?.player = queue
        playerLayer?.videoGravity = fill ? .resizeAspectFill : .resizeAspect
        layout()

        statusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard item.status == .readyToPlay else { return }
            Task { @MainActor in
                self?.layout()
                self?.applyPlaybackIfNeeded()
            }
        }
    }

    func setMuted(_ muted: Bool) {
        player?.isMuted = muted
        player?.volume = muted ? 0 : 1
    }

    func setFill(_ fill: Bool) {
        playerLayer?.videoGravity = fill ? .resizeAspectFill : .resizeAspect
    }

    func play() {
        wantsPlayback = true
        applyPlaybackIfNeeded()
    }

    func pause() {
        wantsPlayback = false
        player?.pause()
        player?.rate = 0
    }

    func layout() {
        playerLayer?.frame = container?.bounds ?? .zero
    }

    func teardown() {
        wantsPlayback = false
        statusObserver = nil
        looper = nil
        player?.pause()
        player = nil
        playerLayer?.player = nil
    }

    private func applyPlaybackIfNeeded() {
        guard wantsPlayback else { return }
        player?.playImmediately(atRate: 1)
    }
}
