import AppKit
import AVFoundation
import Foundation
import ServiceManagement
import UniformTypeIdentifiers

@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    static let allowedVideoTypes: [UTType] = {
        var types: [UTType] = [.mpeg4Movie, .quickTimeMovie]
        if let m4v = UTType(filenameExtension: "m4v") {
            types.append(m4v)
        }
        return types
    }()

    @Published var videoURL: URL?
    @Published var videoDisplayName = ""
    @Published var videoAccessError: String?
    @Published var videoDuration: TimeInterval?
    @Published var previewImage: NSImage?

    @Published var isMuted: Bool {
        didSet { persist(isMuted, key: Keys.isMuted) }
    }

    @Published var scaleToFill: Bool {
        didSet { persist(scaleToFill, key: Keys.scaleToFill) }
    }

    @Published var isManuallyPaused: Bool {
        didSet { persist(isManuallyPaused, key: Keys.isManuallyPaused) }
    }

    @Published var pauseOnBattery: Bool {
        didSet { persist(pauseOnBattery, key: Keys.pauseOnBattery) }
    }

    @Published var pauseOnLowPowerMode: Bool {
        didSet { persist(pauseOnLowPowerMode, key: Keys.pauseOnLowPowerMode) }
    }

    @Published var pauseWhenFullscreen: Bool {
        didSet { persist(pauseWhenFullscreen, key: Keys.pauseWhenFullscreen) }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            guard isReady else { return }
            applyLaunchAtLogin()
        }
    }

    @Published var launchAtLoginError: String?
    @Published var isOnBattery = false
    @Published var isLowPowerMode = false
    @Published var isScreenLocked = false
    @Published var isDisplayAsleep = false

    var shouldEnginePlay: Bool {
        guard videoURL != nil else { return false }
        if isManuallyPaused { return false }
        if isScreenLocked || isDisplayAsleep { return false }
        if pauseOnLowPowerMode && isLowPowerMode { return false }
        if pauseOnBattery && isOnBattery { return false }
        return true
    }

    var menuBarSymbol: String {
        if videoURL == nil { return "play.rectangle" }
        if isManuallyPaused { return "pause.rectangle.fill" }
        return "play.rectangle.fill"
    }

    private let defaults = UserDefaults.standard
    private var isAccessingVideo = false
    private var isReady = false

    private enum Keys {
        static let bookmark = "videoBookmark"
        static let displayName = "videoDisplayName"
        static let isMuted = "isMuted"
        static let scaleToFill = "scaleToFill"
        static let isManuallyPaused = "isManuallyPaused"
        static let pauseOnBattery = "pauseOnBattery"
        static let pauseOnLowPowerMode = "pauseOnLowPowerMode"
        static let pauseWhenFullscreen = "pauseWhenFullscreen"
    }

    private init() {
        isMuted = defaults.object(forKey: Keys.isMuted) as? Bool ?? true
        scaleToFill = defaults.object(forKey: Keys.scaleToFill) as? Bool ?? true
        isManuallyPaused = defaults.bool(forKey: Keys.isManuallyPaused)
        pauseOnBattery = defaults.object(forKey: Keys.pauseOnBattery) as? Bool ?? true
        pauseOnLowPowerMode = defaults.object(forKey: Keys.pauseOnLowPowerMode) as? Bool ?? true
        pauseWhenFullscreen = defaults.object(forKey: Keys.pauseWhenFullscreen) as? Bool ?? true
        videoDisplayName = defaults.string(forKey: Keys.displayName) ?? ""
        launchAtLogin = SMAppService.mainApp.status == .enabled
        isReady = true
    }

    func setVideo(url: URL) {
        guard Self.isSupportedVideo(url) else {
            videoAccessError = "Choose an MP4, MOV, or M4V file."
            return
        }

        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let bookmark = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            stopAccessingVideo()
            defaults.set(bookmark, forKey: Keys.bookmark)
            defaults.set(url.lastPathComponent, forKey: Keys.displayName)
            videoDisplayName = url.lastPathComponent
            videoAccessError = nil
            isManuallyPaused = false
            try activateVideo(from: bookmark)
            DesktopWindowManager.shared.loadCurrentVideo()
        } catch {
            videoAccessError = error.localizedDescription
            videoURL = nil
            videoDuration = nil
            previewImage = nil
        }
    }

    func restorePersistedVideo() {
        guard let bookmark = defaults.data(forKey: Keys.bookmark) else { return }
        do {
            try activateVideo(from: bookmark)
        } catch {
            videoAccessError = "Saved video is no longer available. Choose it again."
            videoURL = nil
            videoDuration = nil
            previewImage = nil
            defaults.removeObject(forKey: Keys.bookmark)
        }
    }

    func clearVideo() {
        stopAccessingVideo()
        defaults.removeObject(forKey: Keys.bookmark)
        defaults.removeObject(forKey: Keys.displayName)
        videoURL = nil
        videoDisplayName = ""
        videoAccessError = nil
        videoDuration = nil
        previewImage = nil
        DesktopWindowManager.shared.clearVideo()
    }

    func toggleManualPlayback() {
        isManuallyPaused.toggle()
        DesktopWindowManager.shared.applyPlaybackState()
    }

    func chooseVideo() {
        VideoPicker.present()
    }

    func stopAccessingVideo() {
        guard isAccessingVideo, let videoURL else {
            isAccessingVideo = false
            return
        }
        videoURL.stopAccessingSecurityScopedResource()
        isAccessingVideo = false
    }

    func syncLaunchAtLoginFromSystem() {
        let enabled = SMAppService.mainApp.status == .enabled
        if launchAtLogin != enabled {
            isReady = false
            launchAtLogin = enabled
            isReady = true
        }
    }

    static func isSupportedVideo(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["mp4", "mov", "m4v"].contains(ext)
    }

    private func activateVideo(from bookmark: Data) throws {
        var isStale = false
        let resolved = try URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        guard resolved.startAccessingSecurityScopedResource() else {
            throw CocoaError(.fileReadNoPermission)
        }

        isAccessingVideo = true
        if isStale, let fresh = try? resolved.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            defaults.set(fresh, forKey: Keys.bookmark)
        }

        videoURL = resolved
        videoDisplayName = resolved.lastPathComponent
        defaults.set(resolved.lastPathComponent, forKey: Keys.displayName)
        loadDuration(for: resolved)
        loadPreview(for: resolved)
    }

    private func loadDuration(for url: URL) {
        Task {
            let asset = AVURLAsset(url: url)
            guard let duration = try? await asset.load(.duration) else { return }
            let seconds = duration.seconds
            guard seconds.isFinite else { return }
            self.videoDuration = seconds
        }
    }

    private func loadPreview(for url: URL) {
        previewImage = nil
        Task {
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 1600, height: 900)
            generator.requestedTimeToleranceBefore = .positiveInfinity
            generator.requestedTimeToleranceAfter = .positiveInfinity
            do {
                let (cgImage, _) = try await generator.image(at: .zero)
                self.previewImage = NSImage(
                    cgImage: cgImage,
                    size: NSSize(width: cgImage.width, height: cgImage.height)
                )
            } catch {
                self.previewImage = nil
            }
        }
    }

    private func persist(_ value: Bool, key: String) {
        guard isReady else { return }
        defaults.set(value, forKey: key)
        DesktopWindowManager.shared.handleSettingsChange()
    }

    private func applyLaunchAtLogin() {
        do {
            launchAtLoginError = nil
            if launchAtLogin {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLoginError = error.localizedDescription
            isReady = false
            launchAtLogin = SMAppService.mainApp.status == .enabled
            isReady = true
        }
    }
}

enum VideoPicker {
    @MainActor
    static func present() {
        let panel = NSOpenPanel()
        panel.title = "Choose a Live Wallpaper"
        panel.prompt = "Use as Wallpaper"
        panel.message = "Short muted clips (5–15 seconds, MP4/MOV) loop like the iPhone Lock Screen."
        panel.allowedContentTypes = SettingsStore.allowedVideoTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        if panel.runModal() == .OK, let url = panel.url {
            SettingsStore.shared.setVideo(url: url)
        }
    }
}
