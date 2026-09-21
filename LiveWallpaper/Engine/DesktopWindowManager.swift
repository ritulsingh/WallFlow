import AppKit

@MainActor
final class DesktopWindowManager {
    static let shared = DesktopWindowManager()

    private var windows: [CGDirectDisplayID: WallpaperWindow] = [:]
    private var loadedURLs: [CGDirectDisplayID: URL] = [:]
    private var observations: [NSObjectProtocol] = []
    private var appliedFrameRateLimit = 0

    private init() {}

    func start() {
        observations.append(
            NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    DesktopWindowManager.shared.rebuildWindows()
                }
            }
        )
        rebuildWindows()
    }

    func stop() {
        for observation in observations {
            NotificationCenter.default.removeObserver(observation)
        }
        observations.removeAll()
        tearDownAll()
    }

    func loadCurrentVideo() {
        loadedURLs.removeAll()
        rebuildWindows()
    }

    func clearVideo() {
        loadedURLs.removeAll()
        tearDownAll()
        DesktopStill.shared.sync()
    }

    func handleSettingsChange() {
        let store = SettingsStore.shared
        if store.frameRateLimit != appliedFrameRateLimit {
            loadedURLs.removeAll()
            rebuildWindows()
            return
        }
        for window in windows.values {
            window.videoController.setAudio(muted: store.isMuted, volume: store.volume)
            window.videoController.setSpeed(store.playbackSpeed)
            window.videoController.setFill(store.scaleToFill)
        }
        applyPlaybackState()
    }

    func orderWindowsFront() {
        for window in windows.values {
            window.orderFrontRegardless()
        }
    }

    func applyPlaybackState() {
        let store = SettingsStore.shared
        let globalPlay = store.shouldEnginePlay
        let covered = store.pauseWhenFullscreen ? PlaybackEnvironment.shared.coveredDisplayIDs : []

        for (displayID, window) in windows {
            if globalPlay && !covered.contains(displayID) {
                window.videoController.play()
            } else {
                window.videoController.pause()
            }
        }
    }

    func rebuildWindows() {
        let store = SettingsStore.shared
        appliedFrameRateLimit = store.frameRateLimit
        let screens = NSScreen.screens
        let currentIDs = Set(screens.map(\.displayID))

        for id in windows.keys where !currentIDs.contains(id) {
            windows[id]?.videoController.teardown()
            windows[id]?.close()
            windows[id] = nil
            loadedURLs[id] = nil
        }

        for screen in screens {
            let id = screen.displayID
            guard let item = store.wallpaperItem(for: id),
                  FileManager.default.fileExists(atPath: item.videoURL.path) else {
                windows[id]?.videoController.teardown()
                windows[id]?.close()
                windows[id] = nil
                loadedURLs[id] = nil
                continue
            }

            let url = item.videoURL
            if let existing = windows[id] {
                existing.match(screen: screen)
                if loadedURLs[id] != url {
                    load(url, into: existing, on: screen)
                    loadedURLs[id] = url
                }
            } else {
                let window = WallpaperWindow(screen: screen)
                load(url, into: window, on: screen)
                windows[id] = window
                loadedURLs[id] = url
            }
        }

        applyPlaybackState()
        orderWindowsFront()
        DesktopStill.shared.sync()
    }

    private func load(_ url: URL, into window: WallpaperWindow, on screen: NSScreen) {
        let store = SettingsStore.shared
        window.videoController.load(
            url: url,
            muted: store.isMuted,
            volume: store.volume,
            fill: store.scaleToFill,
            speed: store.playbackSpeed,
            frameRateLimit: store.frameRateLimit,
            maximumResolution: screen.backingPixelSize
        )
    }

    private func tearDownAll() {
        for window in windows.values {
            window.videoController.teardown()
            window.close()
        }
        windows.removeAll()
        loadedURLs.removeAll()
    }
}
