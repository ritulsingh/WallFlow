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
    private var muted = true
    private var volume: Float = 1
    private var speed: Float = 1
    private var loadGeneration = 0

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

    func load(
        url: URL,
        muted: Bool,
        volume: Double = 1,
        fill: Bool,
        speed: Double = 1,
        frameRateLimit: Int = 0,
        maximumResolution: CGSize? = nil
    ) {
        releasePlayer()
        loadGeneration += 1
        let generation = loadGeneration
        self.muted = muted
        self.volume = Float(volume)
        self.speed = Float(speed)
        playerLayer?.videoGravity = fill ? .resizeAspectFill : .resizeAspect

        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 0
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = false
        if let maximumResolution, maximumResolution.width > 0, maximumResolution.height > 0 {
            item.preferredMaximumResolution = maximumResolution
        }

        guard frameRateLimit > 0 else {
            start(with: item)
            return
        }

        // A video composition is the only way to make AVPlayer render fewer frames per second.
        Task { @MainActor [weak self] in
            let composition = try? await AVMutableVideoComposition.videoComposition(withPropertiesOf: item.asset)
            guard let self, generation == self.loadGeneration else { return }
            if let composition {
                let target = CMTime(value: 1, timescale: CMTimeScale(frameRateLimit))
                if CMTimeCompare(target, composition.frameDuration) > 0 {
                    composition.frameDuration = target
                }
                item.videoComposition = composition
            }
            self.start(with: item)
        }
    }

    func setAudio(muted: Bool, volume: Double) {
        self.muted = muted
        self.volume = Float(volume)
        applyAudio()
    }

    func setSpeed(_ speed: Double) {
        self.speed = Float(speed)
        player?.defaultRate = self.speed
        if wantsPlayback, player?.rate != 0 {
            player?.rate = self.speed
        }
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
        loadGeneration += 1
        releasePlayer()
        playerLayer?.player = nil
    }

    private func start(with item: AVPlayerItem) {
        let queue = AVQueuePlayer()
        queue.automaticallyWaitsToMinimizeStalling = false
        queue.allowsExternalPlayback = false
        queue.preventsDisplaySleepDuringVideoPlayback = false
        queue.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
        queue.defaultRate = speed

        looper = AVPlayerLooper(player: queue, templateItem: item)
        player = queue
        playerLayer?.player = queue
        applyAudio()
        layout()

        statusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard item.status == .readyToPlay else { return }
            Task { @MainActor in
                self?.layout()
                self?.applyPlaybackIfNeeded()
            }
        }

        applyPlaybackIfNeeded()
    }

    private func releasePlayer() {
        statusObserver = nil
        looper = nil
        player?.pause()
        player = nil
    }

    private func applyAudio() {
        player?.isMuted = muted
        player?.volume = muted ? 0 : volume
    }

    private func applyPlaybackIfNeeded() {
        guard wantsPlayback else { return }
        player?.playImmediately(atRate: speed)
    }
}
