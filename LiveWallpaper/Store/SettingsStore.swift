import AppKit
import Foundation
import ServiceManagement
import UniformTypeIdentifiers

struct ConnectedDisplay: Identifiable, Hashable {
    let id: UInt32
    let name: String
}

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
    @Published var selectedID: WallpaperItem.ID? {
        didSet {
            guard isReady, selectedID != oldValue else { return }
            isPreviewing = false
            scheduleEngineUpdate()
        }
    }
    @Published var currentID: WallpaperItem.ID?
    @Published var displayAssignments: [String: String] = [:]
    @Published var isPreviewing = false {
        didSet {
            guard isReady, isPreviewing != oldValue else { return }
            scheduleEngineUpdate()
        }
    }
    @Published var isAppActive = true
    @Published var videoURL: URL?
    @Published var videoAccessError: String?
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

    @Published var pauseWhenUsingOtherApps: Bool {
        didSet { persist(pauseWhenUsingOtherApps, key: Keys.pauseWhenUsingOtherApps) }
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
    @Published var isWorkingInOtherApp = false

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

    var connectedDisplays: [ConnectedDisplay] {
        NSScreen.screens.map { ConnectedDisplay(id: $0.displayID, name: $0.wallFlowName) }
    }

    var hasAnyWallpaper: Bool {
        connectedDisplays.contains { wallpaperItem(for: $0.id) != nil }
    }

    var isBrowsingOtherVideo: Bool {
        guard let selectedID else { return false }
        return !isAssigned(selectedID)
    }

    var shouldEnginePlay: Bool {
        guard hasAnyWallpaper else { return false }
        if isManuallyPaused { return false }
        if isScreenLocked || isDisplayAsleep { return false }
        if pauseOnLowPowerMode && isLowPowerMode { return false }
        if pauseOnBattery && isOnBattery { return false }
        if isPreviewing { return false }
        if isAppActive && isBrowsingOtherVideo { return false }
        if pauseWhenUsingOtherApps && isWorkingInOtherApp { return false }
        return true
    }

    var menuBarSymbol: String {
        if !hasAnyWallpaper { return "play.rectangle" }
        if isManuallyPaused { return "pause.rectangle.fill" }
        return "play.rectangle.fill"
    }

    private let defaults = UserDefaults.standard
    private var isReady = false

    private enum Keys {
        static let currentID = "currentWallpaperID"
        static let displayAssignments = "displayAssignmentsV1"
        static let isMuted = "isMuted"
        static let scaleToFill = "scaleToFill"
        static let isManuallyPaused = "isManuallyPaused"
        static let pauseOnBattery = "pauseOnBatteryV2"
        static let pauseOnLowPowerMode = "pauseOnLowPowerMode"
        static let pauseWhenFullscreen = "pauseWhenFullscreen"
        static let pauseWhenUsingOtherApps = "pauseWhenUsingOtherApps"
    }

    private init() {
        isMuted = defaults.object(forKey: Keys.isMuted) as? Bool ?? true
        scaleToFill = defaults.object(forKey: Keys.scaleToFill) as? Bool ?? true
        isManuallyPaused = defaults.bool(forKey: Keys.isManuallyPaused)
        pauseOnBattery = defaults.object(forKey: Keys.pauseOnBattery) as? Bool ?? false
        pauseOnLowPowerMode = defaults.object(forKey: Keys.pauseOnLowPowerMode) as? Bool ?? true
        pauseWhenFullscreen = defaults.object(forKey: Keys.pauseWhenFullscreen) as? Bool ?? true
        pauseWhenUsingOtherApps = defaults.object(forKey: Keys.pauseWhenUsingOtherApps) as? Bool ?? true
        launchAtLogin = SMAppService.mainApp.status == .enabled
        library = WallpaperLibrary.load()
        displayAssignments = defaults.dictionary(forKey: Keys.displayAssignments) as? [String: String] ?? [:]
        if let stored = defaults.string(forKey: Keys.currentID), let id = UUID(uuidString: stored) {
            currentID = id
            selectedID = id
        } else {
            selectedID = library.first?.id
        }
        migrateLegacyAssignmentIfNeeded()
        refreshDerivedWallpaperState()
        isReady = true
    }

    func wallpaperID(for displayID: UInt32) -> WallpaperItem.ID? {
        if let raw = displayAssignments[String(displayID)], let id = UUID(uuidString: raw) {
            return id
        }
        return nil
    }

    func wallpaperItem(for displayID: UInt32) -> WallpaperItem? {
        guard let id = wallpaperID(for: displayID) else { return nil }
        return library.first { $0.id == id }
    }

    func isAssigned(_ id: WallpaperItem.ID) -> Bool {
        connectedDisplays.contains { wallpaperID(for: $0.id) == id }
    }

    func assignmentLabel(for item: WallpaperItem) -> String? {
        let names = connectedDisplays.compactMap { wallpaperID(for: $0.id) == item.id ? $0.name : nil }
        guard !names.isEmpty else { return nil }
        if names.count == connectedDisplays.count, connectedDisplays.count > 1 {
            return "All displays"
        }
        return names.joined(separator: " · ")
    }

    func restorePersistedVideo() {
        library = WallpaperLibrary.load()
        migrateLegacyAssignmentIfNeeded()
        refreshDerivedWallpaperState()
        DesktopWindowManager.shared.loadCurrentVideo()
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

    func setCurrent(_ item: WallpaperItem, displayIDs: [UInt32]? = nil) {
        isPreviewing = false
        selectedID = item.id
        let targets = displayIDs ?? connectedDisplays.map(\.id)
        guard apply(item, to: targets, userSelected: true) else { return }
        persistAssignments()
        DesktopWindowManager.shared.loadCurrentVideo()
    }

    func togglePreview() {
        guard let selectedItem, !isAssigned(selectedItem.id) else { return }
        isPreviewing.toggle()
    }

    func stopPreview() {
        guard isPreviewing else { return }
        isPreviewing = false
    }

    func removeFromLibrary(_ item: WallpaperItem) {
        removeAssignment(for: item)
        WallpaperLibrary.delete(item)
        library.removeAll { $0.id == item.id }
        WallpaperLibrary.save(library)
        if selectedID == item.id {
            selectedID = currentID ?? library.first?.id
        }
    }

    func removeAssignment(for item: WallpaperItem) {
        displayAssignments = displayAssignments.filter { $0.value != item.id.uuidString }
        persistAssignments()
        refreshDerivedWallpaperState()
        DesktopWindowManager.shared.loadCurrentVideo()
    }

    func clearVideo() {
        isPreviewing = false
        displayAssignments.removeAll()
        persistAssignments()
        currentID = nil
        defaults.removeObject(forKey: Keys.currentID)
        videoURL = nil
        videoAccessError = nil
        DesktopWindowManager.shared.clearVideo()
    }

    func toggleManualPlayback() {
        isManuallyPaused.toggle()
        DesktopWindowManager.shared.applyPlaybackState()
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

    @discardableResult
    private func apply(_ item: WallpaperItem, to displayIDs: [UInt32], userSelected: Bool) -> Bool {
        guard FileManager.default.fileExists(atPath: item.videoURL.path) else {
            videoAccessError = "This clip is missing. Import it again."
            return false
        }

        for displayID in displayIDs {
            displayAssignments[String(displayID)] = item.id.uuidString
        }
        currentID = item.id
        selectedID = item.id
        defaults.set(item.id.uuidString, forKey: Keys.currentID)
        videoURL = item.videoURL
        videoAccessError = nil
        if userSelected {
            isManuallyPaused = false
        }
        return true
    }

    private func migrateLegacyAssignmentIfNeeded() {
        guard displayAssignments.isEmpty, let currentID else { return }
        for display in connectedDisplays {
            displayAssignments[String(display.id)] = currentID.uuidString
        }
        persistAssignments()
    }

    private func refreshDerivedWallpaperState() {
        let assigned = connectedDisplays.compactMap { wallpaperItem(for: $0.id) }
        if let currentID, assigned.contains(where: { $0.id == currentID }) {
            videoURL = library.first { $0.id == currentID }?.videoURL
        } else if let first = assigned.first {
            currentID = first.id
            defaults.set(first.id.uuidString, forKey: Keys.currentID)
            videoURL = first.videoURL
        } else {
            currentID = nil
            videoURL = nil
        }
    }

    private func persistAssignments() {
        defaults.set(displayAssignments, forKey: Keys.displayAssignments)
        refreshDerivedWallpaperState()
    }

    private func persist(_ value: Bool, key: String) {
        guard isReady else { return }
        defaults.set(value, forKey: key)
        scheduleEngineUpdate()
    }

    private func scheduleEngineUpdate() {
        Task { @MainActor in
            DesktopWindowManager.shared.handleSettingsChange()
        }
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
