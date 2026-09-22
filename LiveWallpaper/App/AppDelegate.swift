import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowObservations: [NSObjectProtocol] = []
    private var dockVisibilityTimer: Timer?

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
        dockVisibilityTimer?.invalidate()
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
    ///
    /// SwiftUI's `Window(id:)` scene is a reopenable singleton: clicking its close button orders
    /// the window out instead of fully closing it, so `NSWindow.willCloseNotification` never
    /// fires. Notifications alone can't be trusted here, so a cheap periodic check backs them up.
    private func observeDockVisibility() {
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            NSWindow.didBecomeKeyNotification,
            NSWindow.willCloseNotification,
            NSApplication.didHideNotification,
            NSApplication.didUnhideNotification
        ]
        for name in names {
            windowObservations.append(
                center.addObserver(forName: name, object: nil, queue: .main) { _ in
                    Task { @MainActor in AppDelegate.updateDockVisibility() }
                }
            )
        }

        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in AppDelegate.updateDockVisibility() }
        }
        timer.tolerance = 0.3
        dockVisibilityTimer = timer

        Task { @MainActor in AppDelegate.updateDockVisibility() }
    }

    private static func updateDockVisibility() {
        // Excluding chrome (WallpaperWindow, the menu bar's own NSStatusBarWindow, its popover,
        // etc.) turned out unreliable — SwiftUI's own main-window wrapper also reports
        // isExcludedFromWindowsMenu = true, and NSStatusBarWindow is permanently visible, so that
        // approach always saw a "visible app window". Whitelisting the SwiftUI-managed window
        // class used by the Window(id:) and Settings scenes is the reliable signal instead.
        let hasVisibleAppWindow = NSApp.windows.contains { window in
            window.isVisible && String(describing: type(of: window)) == "AppKitWindow"
        }
        let target: NSApplication.ActivationPolicy = hasVisibleAppWindow ? .regular : .accessory
        if NSApp.activationPolicy() != target {
            NSApp.setActivationPolicy(target)
        }
    }
}
