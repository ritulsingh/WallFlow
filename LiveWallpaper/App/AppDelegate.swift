import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowObservations: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        SettingsStore.shared.restorePersistedVideo()
        SettingsStore.shared.syncLaunchAtLoginFromSystem()
        PlaybackEnvironment.shared.start()
        DesktopWindowManager.shared.start()
        UpdateController.shared.start()
        RotationScheduler.shared.reschedule()
        NSApp.servicesProvider = self
        observeDockVisibility()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        SettingsStore.shared.isAppActive = true
        DesktopWindowManager.shared.applyPlaybackState()
    }

    func applicationDidResignActive(_ notification: Notification) {
        SettingsStore.shared.stopPreview()
        SettingsStore.shared.isAppActive = false
        DesktopWindowManager.shared.applyPlaybackState()
    }

    func applicationWillTerminate(_ notification: Notification) {
        RotationScheduler.shared.stop()
        DesktopWindowManager.shared.stop()
        PlaybackEnvironment.shared.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        SettingsStore.shared.importDropped(url: url)
    }

    /// Backs the Finder "Set as WallFlow Wallpaper" Services menu item (see NSServices in Info.plist).
    @objc func setAsWallpaperService(
        _ pasteboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        let urls = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] ?? []

        guard let url = urls.first(where: WallpaperLibrary.isSupportedVideo) else {
            error.pointee = "WallFlow can't use that file as a wallpaper." as NSString
            return
        }

        SettingsStore.shared.importDropped(url: url)
    }

    /// WallFlow is a background agent (LSUIElement) so it doesn't clutter the Dock or ⌘-Tab
    /// while only the menu bar is in use. The Dock icon reappears whenever the main window or
    /// Settings is actually open, and hides again once they're closed.
    private func observeDockVisibility() {
        let center = NotificationCenter.default
        let immediate: [Notification.Name] = [
            NSWindow.didBecomeKeyNotification,
            NSApplication.didHideNotification,
            NSApplication.didUnhideNotification
        ]
        for name in immediate {
            windowObservations.append(
                center.addObserver(forName: name, object: nil, queue: .main) { _ in
                    Task { @MainActor in AppDelegate.updateDockVisibility() }
                }
            )
        }
        // Deferred so NSApp.windows has already dropped the closed window by the time we check.
        windowObservations.append(
            center.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { _ in
                DispatchQueue.main.async { AppDelegate.updateDockVisibility() }
            }
        )
        Task { @MainActor in AppDelegate.updateDockVisibility() }
    }

    private static func updateDockVisibility() {
        let hasVisibleAppWindow = NSApp.windows.contains { window in
            window.isVisible && !window.isExcludedFromWindowsMenu && !(window is NSPanel)
        }
        let target: NSApplication.ActivationPolicy = hasVisibleAppWindow ? .regular : .accessory
        if NSApp.activationPolicy() != target {
            NSApp.setActivationPolicy(target)
        }
    }
}
