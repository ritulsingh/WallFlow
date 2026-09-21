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
        types.append(.gif)
        for ext in ["m4v", "webm", "mkv", "avi"] {
            if let type = UTType(filenameExtension: ext) {
                types.append(type)
            }
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
    @Published var isShowingURLImporter = false
    @Published var libraryFilter: LibraryFilter = .all

    @Published var librarySort: LibrarySort {
        didSet {
            guard isReady else { return }
            defaults.set(librarySort.rawValue, forKey: Keys.librarySort)
        }
    }

    @Published var volume: Double {
        didSet { persist(volume, key: Keys.volume) }
    }

    @Published var playbackSpeed: Double {
        didSet { persist(playbackSpeed, key: Keys.playbackSpeed) }
    }

    @Published var frameRateLimit: Int {
        didSet { persist(frameRateLimit, key: Keys.frameRateLimit) }
    }

    @Published var setStaticDesktop: Bool {
        didSet {
            guard isReady else { return }
            defaults.set(setStaticDesktop, forKey: Keys.setStaticDesktop)
            DesktopStill.shared.sync()
        }
    }

    @Published var rotationEnabled: Bool {
        didSet { persistRotation(rotationEnabled, key: Keys.rotationEnabled) }
    }

    @Published var rotationIntervalMinutes: Int {
        didSet { persistRotation(rotationIntervalMinutes, key: Keys.rotationInterval) }
    }

    @Published var rotationShuffle: Bool {
        didSet { persistRotation(rotationShuffle, key: Keys.rotationShuffle) }
    }

    @Published var rotationSourceKey: String {
        didSet { persistRotation(rotationSourceKey, key: Keys.rotationSource) }
    }

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

    var collections: [String] {
        Set(library.compactMap(\.collection)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var favoriteCount: Int {
        library.filter(\.isFavorite).count
    }

    var activeFilter: LibraryFilter {
        if case .collection(let name) = libraryFilter, !collections.contains(name) {
            return .all
        }
        return libraryFilter
    }

    var filteredLibrary: [WallpaperItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filter = activeFilter
        var items = library.filter { filter.matches($0) }
        if !query.isEmpty {
            items = items.filter {
                $0.displayName.localizedCaseInsensitiveContains(query)
                    || $0.prettyName.localizedCaseInsensitiveContains(query)
            }
        }
        return items.sorted(by: librarySort.areInIncreasingOrder)
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
        static let volume = "volume"
        static let playbackSpeed = "playbackSpeed"
        static let frameRateLimit = "frameRateLimit"
        static let setStaticDesktop = "setStaticDesktop"
        static let librarySort = "librarySort"
        static let rotationEnabled = "rotationEnabled"
        static let rotationInterval = "rotationIntervalMinutes"
        static let rotationShuffle = "rotationShuffle"
        static let rotationSource = "rotationSource"
    }

    private init() {
        isMuted = defaults.object(forKey: Keys.isMuted) as? Bool ?? true
        scaleToFill = defaults.object(forKey: Keys.scaleToFill) as? Bool ?? true
        isManuallyPaused = defaults.bool(forKey: Keys.isManuallyPaused)
        pauseOnBattery = defaults.object(forKey: Keys.pauseOnBattery) as? Bool ?? false
        pauseOnLowPowerMode = defaults.object(forKey: Keys.pauseOnLowPowerMode) as? Bool ?? true
        pauseWhenFullscreen = defaults.object(forKey: Keys.pauseWhenFullscreen) as? Bool ?? true
        pauseWhenUsingOtherApps = defaults.object(forKey: Keys.pauseWhenUsingOtherApps) as? Bool ?? true
        volume = defaults.object(forKey: Keys.volume) as? Double ?? 1
        playbackSpeed = defaults.object(forKey: Keys.playbackSpeed) as? Double ?? 1
        frameRateLimit = defaults.object(forKey: Keys.frameRateLimit) as? Int ?? 0
        setStaticDesktop = defaults.bool(forKey: Keys.setStaticDesktop)
        rotationEnabled = defaults.bool(forKey: Keys.rotationEnabled)
        rotationIntervalMinutes = defaults.object(forKey: Keys.rotationInterval) as? Int ?? 30
        rotationShuffle = defaults.object(forKey: Keys.rotationShuffle) as? Bool ?? true
        rotationSourceKey = defaults.string(forKey: Keys.rotationSource) ?? "all"
        librarySort = defaults.string(forKey: Keys.librarySort).flatMap(LibrarySort.init(rawValue:)) ?? .recent
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
            videoAccessError = "Choose an MP4, MOV, M4V, GIF, WebM, or MKV file."
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
        guard apply(item, to: targets, userSelected: true, select: true) else { return }
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

    func toggleFavorite(_ item: WallpaperItem) {
        update(item.id) { $0.favorite = !$0.isFavorite }
    }

    func setCollection(_ name: String?, for item: WallpaperItem) {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        update(item.id) { $0.collection = (trimmed?.isEmpty ?? true) ? nil : trimmed }
    }

    func rotateWallpaper(force: Bool = false) {
        guard hasAnyWallpaper else { return }
        if !force && (isManuallyPaused || isScreenLocked || isDisplayAsleep) { return }

        let pool = rotationPool()
        guard pool.count > 1 else { return }

        let next: WallpaperItem?
        if rotationShuffle {
            next = pool.filter { $0.id != currentID }.randomElement()
        } else if let currentID, let index = pool.firstIndex(where: { $0.id == currentID }) {
            next = pool[(index + 1) % pool.count]
        } else {
            next = pool.first
        }

        guard let next, next.id != currentID else { return }
        let targets = connectedDisplays.map(\.id).filter { wallpaperID(for: $0) != nil }
        guard apply(next, to: targets, userSelected: false, select: !isAppActive) else { return }
        persistAssignments()
        DesktopWindowManager.shared.loadCurrentVideo()
    }

    func importRemoteVideo(from url: URL) async throws {
        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            throw MediaImportError.invalidURL
        }

        isImporting = true
        videoAccessError = nil
        do {
            let (temporary, response) = try await URLSession.shared.download(from: url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw MediaImportError.badResponse(http.statusCode)
            }
            let local = try Self.moveDownload(temporary, response: response, sourceURL: url)
            defer { try? FileManager.default.removeItem(at: local.deletingLastPathComponent()) }
            let item = try await Task.detached(priority: .userInitiated) {
                try WallpaperLibrary.importVideo(from: local)
            }.value
            finishImport([item], error: nil)
        } catch {
            isImporting = false
            throw error
        }
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

    private static func moveDownload(_ temporary: URL, response: URLResponse, sourceURL: URL) throws -> URL {
        var name = sourceURL.lastPathComponent.removingPercentEncoding ?? sourceURL.lastPathComponent
        var ext = (name as NSString).pathExtension.lowercased()

        if !MediaConverter.supportedExtensions.contains(ext) {
            let mimeExtensions = [
                "video/mp4": "mp4", "video/quicktime": "mov", "video/x-m4v": "m4v",
                "image/gif": "gif", "video/webm": "webm", "video/x-matroska": "mkv"
            ]
            guard let mime = response.mimeType?.lowercased(), let mapped = mimeExtensions[mime] else {
                throw MediaImportError.unsupportedDownload
            }
            ext = mapped
            name = ((name as NSString).deletingPathExtension.isEmpty ? "Downloaded Video" : (name as NSString).deletingPathExtension) + "." + ext
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("wallflow-download-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent(name)
        try FileManager.default.moveItem(at: temporary, to: destination)
        return destination
    }

    private func update(_ id: WallpaperItem.ID, _ change: (inout WallpaperItem) -> Void) {
        guard let index = library.firstIndex(where: { $0.id == id }) else { return }
        change(&library[index])
        WallpaperLibrary.save(library)
    }

    private func rotationPool() -> [WallpaperItem] {
        let filter = LibraryFilter(storageKey: rotationSourceKey)
        var items = library.filter { filter.matches($0) }
        if items.isEmpty {
            items = library
        }
        return items.sorted { $0.addedAt < $1.addedAt }
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
    private func apply(_ item: WallpaperItem, to displayIDs: [UInt32], userSelected: Bool, select: Bool) -> Bool {
        guard FileManager.default.fileExists(atPath: item.videoURL.path) else {
            videoAccessError = "This clip is missing. Import it again."
            return false
        }

        for displayID in displayIDs {
            displayAssignments[String(displayID)] = item.id.uuidString
        }
        currentID = item.id
        if select {
            selectedID = item.id
        }
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

    private func persist(_ value: Any, key: String) {
        guard isReady else { return }
        defaults.set(value, forKey: key)
        scheduleEngineUpdate()
    }

    private func persistRotation(_ value: Any, key: String) {
        guard isReady else { return }
        defaults.set(value, forKey: key)
        RotationScheduler.shared.reschedule()
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
