import AppKit
import CoreGraphics

@MainActor
final class FullscreenMonitor {
    static let shared = FullscreenMonitor()

    private(set) var coveredDisplayIDs: Set<CGDirectDisplayID> = []
    private var timer: Timer?
    private var observations: [NSObjectProtocol] = []

    private init() {}

    func start() {
        refreshFullscreen()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                FullscreenMonitor.shared.refreshFullscreen()
            }
        }
        timer?.tolerance = 0.25

        let workspace = NSWorkspace.shared.notificationCenter
        observations.append(
            workspace.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { _ in
                Task { @MainActor in
                    SettingsStore.shared.isDisplayAsleep = true
                    DesktopWindowManager.shared.applyPlaybackState()
                }
            }
        )
        observations.append(
            workspace.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { _ in
                Task { @MainActor in
                    SettingsStore.shared.isDisplayAsleep = false
                    DesktopWindowManager.shared.applyPlaybackState()
                    DesktopWindowManager.shared.orderWindowsFront()
                }
            }
        )
        observations.append(
            workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
                Task { @MainActor in
                    SettingsStore.shared.isDisplayAsleep = false
                    DesktopWindowManager.shared.applyPlaybackState()
                }
            }
        )

        let distributed = DistributedNotificationCenter.default()
        observations.append(
            distributed.addObserver(forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { _ in
                Task { @MainActor in
                    SettingsStore.shared.isScreenLocked = true
                    DesktopWindowManager.shared.applyPlaybackState()
                }
            }
        )
        observations.append(
            distributed.addObserver(forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { _ in
                Task { @MainActor in
                    SettingsStore.shared.isScreenLocked = false
                    DesktopWindowManager.shared.applyPlaybackState()
                }
            }
        )
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        for observation in observations {
            DistributedNotificationCenter.default().removeObserver(observation)
            NSWorkspace.shared.notificationCenter.removeObserver(observation)
            NotificationCenter.default.removeObserver(observation)
        }
        observations.removeAll()
    }

    func refreshFullscreen() {
        let next = Self.detectCoveredDisplays()
        guard next != coveredDisplayIDs else { return }
        coveredDisplayIDs = next
        DesktopWindowManager.shared.applyPlaybackState()
    }

    /// Uses window bounds and layer only so Screen Recording permission is not required.
    private static func detectCoveredDisplays() -> Set<CGDirectDisplayID> {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let infoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        let ourPID = ProcessInfo.processInfo.processIdentifier
        let desktopLayer = Int(CGWindowLevelForKey(.desktopIconWindow))
        let statusLayer = Int(CGWindowLevelForKey(.statusWindow))
        var covered = Set<CGDirectDisplayID>()

        for screen in NSScreen.screens {
            let target = screen.quartzFrame
            for info in infoList {
                if let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t, ownerPID == ourPID {
                    continue
                }
                guard let layer = info[kCGWindowLayer as String] as? Int,
                      layer >= 0,
                      layer < statusLayer,
                      layer > desktopLayer
                else {
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
