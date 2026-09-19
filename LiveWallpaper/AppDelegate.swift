import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        SettingsStore.shared.restorePersistedVideo()
        SettingsStore.shared.syncLaunchAtLoginFromSystem()
        PowerMonitor.shared.start()
        FullscreenMonitor.shared.start()
        AppActivityMonitor.shared.start()
        DesktopWindowManager.shared.start()
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
        DesktopWindowManager.shared.stop()
        AppActivityMonitor.shared.stop()
        FullscreenMonitor.shared.stop()
        PowerMonitor.shared.stop()
        SettingsStore.shared.stopAccessingVideo()
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
}
