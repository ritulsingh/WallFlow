import AppKit

@MainActor
final class AppActivityMonitor {
    static let shared = AppActivityMonitor()

    private var observations: [NSObjectProtocol] = []
    private var timer: Timer?

    private init() {}

    func start() {
        refresh()

        let workspace = NSWorkspace.shared.notificationCenter
        let names: [NSNotification.Name] = [
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.didDeactivateApplicationNotification,
            NSWorkspace.activeSpaceDidChangeNotification,
        ]

        for name in names {
            observations.append(
                workspace.addObserver(forName: name, object: nil, queue: .main) { _ in
                    Task { @MainActor in
                        AppActivityMonitor.shared.refresh()
                    }
                }
            )
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                AppActivityMonitor.shared.refresh()
            }
        }
        timer?.tolerance = 0.25
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        for observation in observations {
            NSWorkspace.shared.notificationCenter.removeObserver(observation)
        }
        observations.removeAll()
    }

    func refresh() {
        let store = SettingsStore.shared
        let workingInOtherApp = Self.isWorkingInOtherApp()
        guard store.isWorkingInOtherApp != workingInOtherApp else { return }
        store.isWorkingInOtherApp = workingInOtherApp
        if workingInOtherApp {
            store.stopPreview()
        }
        DesktopWindowManager.shared.applyPlaybackState()
    }

    private static func isWorkingInOtherApp() -> Bool {
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
            return false
        }
        if bundleID == Bundle.main.bundleIdentifier { return false }
        if bundleID == "com.apple.finder" { return false }
        if bundleID.hasPrefix("com.apple.loginwindow") { return false }
        return true
    }
}
