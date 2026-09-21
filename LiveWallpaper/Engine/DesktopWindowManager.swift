import AppKit

@MainActor
final class DesktopWindowManager {
    static let shared = DesktopWindowManager()

    private var windows: [CGDirectDisplayID: WallpaperWindow] = [:]
    private var observations: [NSObjectProtocol] = []
    private var loadedVideoURL: URL?

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
        loadedVideoURL = nil
        rebuildWindows()
    }

    func clearVideo() {
        loadedVideoURL = nil
        tearDownAll()
    }

    func handleSettingsChange() {
        let store = SettingsStore.shared
        for window in windows.values {
            window.videoController.setMuted(store.isMuted)
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
        guard let videoURL = store.videoURL else {
            tearDownAll()
            return
        }

        let screens = NSScreen.screens
        let currentIDs = Set(screens.map(\.displayID))

        for id in windows.keys where !currentIDs.contains(id) {
            windows[id]?.videoController.teardown()
            windows[id]?.close()
            windows[id] = nil
        }

        let videoChanged = loadedVideoURL != videoURL
        for screen in screens {
            let id = screen.displayID
            if let existing = windows[id] {
                existing.match(screen: screen)
                if videoChanged {
                    existing.videoController.load(
                        url: videoURL,
                        muted: store.isMuted,
                        fill: store.scaleToFill,
                        maximumResolution: screen.backingPixelSize
                    )
                }
            } else {
                let window = WallpaperWindow(screen: screen)
                window.videoController.load(
                    url: videoURL,
                    muted: store.isMuted,
                    fill: store.scaleToFill,
                    maximumResolution: screen.backingPixelSize
                )
                windows[id] = window
            }
        }

        loadedVideoURL = videoURL
        applyPlaybackState()
        orderWindowsFront()
    }

    private func tearDownAll() {
        for window in windows.values {
            window.videoController.teardown()
            window.close()
        }
        windows.removeAll()
        loadedVideoURL = nil
    }
}
