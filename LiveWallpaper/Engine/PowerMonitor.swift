import Foundation
import IOKit.ps

@MainActor
final class PowerMonitor {
    static let shared = PowerMonitor()

    private var runLoopSource: CFRunLoopSource?
    private var powerStateObserver: NSObjectProtocol?

    private init() {}

    func start() {
        refresh()

        if let source = IOPSNotificationCreateRunLoopSource({ _ in
            DispatchQueue.main.async {
                PowerMonitor.shared.refresh()
            }
        }, nil)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = source
        }

        powerStateObserver = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                PowerMonitor.shared.refresh()
            }
        }
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
            self.runLoopSource = nil
        }
        if let powerStateObserver {
            NotificationCenter.default.removeObserver(powerStateObserver)
            self.powerStateObserver = nil
        }
    }

    func refresh() {
        let store = SettingsStore.shared
        store.isOnBattery = Self.isRunningOnBattery()
        store.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        DesktopWindowManager.shared.applyPlaybackState()
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
}
