import AppKit
import Foundation
import ServiceManagement
import UniformTypeIdentifiers

@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    static let allowedVideoTypes: [UTType] = {
        var types: [UTType] = [.mpeg4Movie, .quickTimeMovie, .movie]
        if let m4v = UTType(filenameExtension: "m4v") {
            types.append(m4v)
        }
        return types
    }()

    @Published var library: [WallpaperItem] = []
    @Published var selectedID: WallpaperItem.ID?
    @Published var currentID: WallpaperItem.ID?
    @Published var videoURL: URL?
    @Published var videoDisplayName = ""
    @Published var videoAccessError: String?
    @Published var videoDuration: TimeInterval?
    @Published var previewImage: NSImage?
    @Published var searchText = ""
    @Published var isShowingImporter = false
    @Published var isImporting = false

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

    var selectedItem: WallpaperItem? {
        library.first { $0.id == selectedID }
    }

    var currentItem: WallpaperItem? {
        library.first { $0.id == currentID }
    }

    var filteredLibrary: [WallpaperItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let items = library.sorted { $0.addedAt > $1.addedAt }
        guard !query.isEmpty else { return items }
        return items.filter { $0.displayName.localizedCaseInsensitiveContains(query) }
    }

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
    private var isReady = false

    private enum Keys {
        static let currentID = "currentWallpaperID"
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
        launchAtLogin = SMAppService.mainApp.status == .enabled
        library = WallpaperLibrary.load()
        if let stored = defaults.string(forKey: Keys.currentID), let id = UUID(uuidString: stored) {
            currentID = id
            selectedID = id
        } else {
            selectedID = library.first?.id
        }
        isReady = true
    }

    func restorePersistedVideo() {
        library = WallpaperLibrary.load()
        if let currentID, let item = library.first(where: { $0.id == currentID }) {
            apply(item, userSelected: false)
            return
        }
        currentID = nil
        videoURL = nil
    }

    func chooseVideo() {
        isShowingImporter = true
    }

    func importDropped(url: URL) {
        importVideos(from: [url])
    }

    func importVideos(from result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            importVideos(from: urls)
        case .failure(let error):
            videoAccessError = error.localizedDescription
        }
    }

    func importVideos(from urls: [URL]) {
        let supported = urls.filter { Self.isSupportedVideo($0) }
        guard !supported.isEmpty else {
            videoAccessError = "Choose an MP4, MOV, or M4V file."
            return
        }

        isImporting = true
        videoAccessError = nil

        Task.detached(priority: .userInitiated) {
            var imported: [WallpaperItem] = []
            var lastError: String?
            for url in supported {
                do {
                    imported.append(try WallpaperLibrary.importVideo(from: url))
                } catch {
                    lastError = error.localizedDescription
                }
            }

            let importedCopy = imported
            let lastErrorCopy = lastError
            await MainActor.run {
                SettingsStore.shared.finishImport(importedCopy, error: lastErrorCopy)
            }
        }
    }

    func setCurrent(_ item: WallpaperItem) {
        selectedID = item.id
        apply(item, userSelected: true)
    }

    func removeFromLibrary(_ item: WallpaperItem) {
        if currentID == item.id {
            clearVideo()
        }
        WallpaperLibrary.delete(item)
        library.removeAll { $0.id == item.id }
        WallpaperLibrary.save(library)
        if selectedID == item.id {
            selectedID = currentID ?? library.first?.id
        }
    }

    func clearVideo() {
        currentID = nil
        defaults.removeObject(forKey: Keys.currentID)
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

    func stopAccessingVideo() {}

    func syncLaunchAtLoginFromSystem() {
        let enabled = SMAppService.mainApp.status == .enabled
        if launchAtLogin != enabled {
            isReady = false
            launchAtLogin = enabled
            isReady = true
        }
    }

    static func isSupportedVideo(_ url: URL) -> Bool {
        WallpaperLibrary.isSupportedVideo(url)
    }

    private func finishImport(_ imported: [WallpaperItem], error: String?) {
        isImporting = false
        if !imported.isEmpty {
            library.insert(contentsOf: imported, at: 0)
            WallpaperLibrary.save(library)
            if let latest = imported.last {
                setCurrent(latest)
            }
        }
        if imported.isEmpty {
            videoAccessError = error ?? "WallFlow couldn’t import that video."
        }
    }

    private func apply(_ item: WallpaperItem, userSelected: Bool) {
        guard FileManager.default.fileExists(atPath: item.videoURL.path) else {
            videoAccessError = "This clip is missing. Import it again."
            return
        }

        currentID = item.id
        selectedID = item.id
        defaults.set(item.id.uuidString, forKey: Keys.currentID)
        videoURL = item.videoURL
        videoDisplayName = item.displayName
        videoDuration = item.duration
        previewImage = item.thumbnailImage
        videoAccessError = nil
        if userSelected {
            isManuallyPaused = false
        }
        DesktopWindowManager.shared.loadCurrentVideo()
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
