import AppKit
import CoreGraphics
import Foundation
import IOKit.ps

@MainActor
final class PlaybackEnvironment {
    static let shared = PlaybackEnvironment()

    private(set) var coveredDisplayIDs: Set<CGDirectDisplayID> = []

    private var runLoopSource: CFRunLoopSource?
    private var timer: Timer?
    private var observations: [NSObjectProtocol] = []

    private init() {}

    func start() {
        refreshPower()
        refreshFrontmostApp()
        refreshFullscreen()

        if let source = IOPSNotificationCreateRunLoopSource({ _ in
            DispatchQueue.main.async {
                PlaybackEnvironment.shared.refreshPower()
            }
        }, nil)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = source
        }

        observe(NotificationCenter.default, .NSProcessInfoPowerStateDidChange) {
            PlaybackEnvironment.shared.refreshPower()
        }

        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.screensDidSleepNotification) {
            SettingsStore.shared.isDisplayAsleep = true
            DesktopWindowManager.shared.applyPlaybackState()
        }
        observe(workspace, NSWorkspace.screensDidWakeNotification) {
            SettingsStore.shared.isDisplayAsleep = false
            DesktopWindowManager.shared.applyPlaybackState()
            DesktopWindowManager.shared.orderWindowsFront()
        }
        observe(workspace, NSWorkspace.didWakeNotification) {
            SettingsStore.shared.isDisplayAsleep = false
            DesktopWindowManager.shared.applyPlaybackState()
        }
        observe(workspace, NSWorkspace.didActivateApplicationNotification) {
            PlaybackEnvironment.shared.refreshFrontmostApp()
        }
        observe(workspace, NSWorkspace.didDeactivateApplicationNotification) {
            PlaybackEnvironment.shared.refreshFrontmostApp()
        }
        observe(workspace, NSWorkspace.activeSpaceDidChangeNotification) {
            PlaybackEnvironment.shared.refreshFrontmostApp()
            PlaybackEnvironment.shared.refreshFullscreen()
        }

        let distributed = DistributedNotificationCenter.default()
        observe(distributed, Notification.Name("com.apple.screenIsLocked")) {
            SettingsStore.shared.isScreenLocked = true
            DesktopWindowManager.shared.applyPlaybackState()
        }
        observe(distributed, Notification.Name("com.apple.screenIsUnlocked")) {
            SettingsStore.shared.isScreenLocked = false
            DesktopWindowManager.shared.applyPlaybackState()
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            Task { @MainActor in
                PlaybackEnvironment.shared.refreshFrontmostApp()
                PlaybackEnvironment.shared.refreshFullscreen()
            }
        }
        timer?.tolerance = 0.4
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
            self.runLoopSource = nil
        }
        for observation in observations {
            DistributedNotificationCenter.default().removeObserver(observation)
            NSWorkspace.shared.notificationCenter.removeObserver(observation)
            NotificationCenter.default.removeObserver(observation)
        }
        observations.removeAll()
    }

    func refreshPower() {
        let onBattery = Self.isRunningOnBattery()
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        let store = SettingsStore.shared
        store.isOnBattery = onBattery
        store.isLowPowerMode = lowPower
        DesktopWindowManager.shared.applyPlaybackState()
    }

    func refreshFrontmostApp() {
        let store = SettingsStore.shared
        let workingInOtherApp = Self.isWorkingInOtherApp()
        guard store.isWorkingInOtherApp != workingInOtherApp else { return }
        store.isWorkingInOtherApp = workingInOtherApp
        if workingInOtherApp {
            store.stopPreview()
        }
        DesktopWindowManager.shared.applyPlaybackState()
    }

    func refreshFullscreen() {
        let next = Self.detectCoveredDisplays()
        guard next != coveredDisplayIDs else { return }
        coveredDisplayIDs = next
        DesktopWindowManager.shared.applyPlaybackState()
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, handler: @escaping @MainActor () -> Void) {
        observations.append(
            center.addObserver(forName: name, object: nil, queue: .main) { _ in
                Task { @MainActor in
                    handler()
                }
            }
        )
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

    private static func isRunningOnBattery() -> Bool {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else {
            return false
        }

        for source in sources {
            guard let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
                  let state = info[kIOPSPowerSourceStateKey] as? String
            else {
                continue
            }
            if state == kIOPSBatteryPowerValue {
                return true
            }
        }
        return false
    }

    /// Uses window bounds and layer only so Screen Recording permission is not required.
    private static func detectCoveredDisplays() -> Set<CGDirectDisplayID> {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let infoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        let ourPID = ProcessInfo.processInfo.processIdentifier
        var covered = Set<CGDirectDisplayID>()

        for screen in NSScreen.screens {
            let target = screen.quartzFrame
            for info in infoList {
                if let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t, ownerPID == ourPID {
                    continue
                }
                guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else {
                    continue
                }
                if let alpha = info[kCGWindowAlpha as String] as? CGFloat, alpha < 0.99 {
                    continue
                }
                guard let bounds = info[kCGWindowBounds as String] as? [String: CGFloat] else {
                    continue
                }

                let windowFrame = CGRect(
                    x: bounds["X"] ?? 0,
                    y: bounds["Y"] ?? 0,
                    width: bounds["Width"] ?? 0,
                    height: bounds["Height"] ?? 0
                )

                let widthMatch = abs(windowFrame.width - target.width) <= 8
                let heightMatch = abs(windowFrame.height - target.height) <= 8
                let originMatch = abs(windowFrame.origin.x - target.origin.x) <= 8
                    && abs(windowFrame.origin.y - target.origin.y) <= 8

                if widthMatch && heightMatch && originMatch {
                    covered.insert(screen.displayID)
                    break
                }
            }
        }

        return covered
    }
}
