import AppKit
import AVFoundation

@MainActor
final class VideoLoopController {
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var playerLayer: AVPlayerLayer?
    private weak var container: NSView?

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
    }

    func load(url: URL, muted: Bool, fill: Bool) {
        looper = nil
        player?.pause()
        player = nil

        let item = AVPlayerItem(url: url)
        let queue = AVQueuePlayer()
        queue.isMuted = muted
        queue.automaticallyWaitsToMinimizeStalling = false
        queue.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible

        looper = AVPlayerLooper(player: queue, templateItem: item)
        player = queue
        playerLayer?.player = queue
        playerLayer?.videoGravity = fill ? .resizeAspectFill : .resizeAspect
        layout()
    }

    func setMuted(_ muted: Bool) {
        player?.isMuted = muted
    }

    func setFill(_ fill: Bool) {
        playerLayer?.videoGravity = fill ? .resizeAspectFill : .resizeAspect
    }

    func play() {
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    func layout() {
        playerLayer?.frame = container?.bounds ?? .zero
    }

    func teardown() {
        looper = nil
        player?.pause()
        player = nil
        playerLayer?.player = nil
    }
}
