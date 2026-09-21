import Foundation

@MainActor
final class RotationScheduler {
    static let shared = RotationScheduler()

    private var timer: Timer?

    private init() {}

    func reschedule() {
        timer?.invalidate()
        timer = nil

        let store = SettingsStore.shared
        guard store.rotationEnabled else { return }

        let interval = TimeInterval(max(1, store.rotationIntervalMinutes) * 60)
        let next = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor in
                SettingsStore.shared.rotateWallpaper()
            }
        }
        next.tolerance = interval * 0.1
        timer = next
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
