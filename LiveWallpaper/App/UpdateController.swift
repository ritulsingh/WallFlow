import Sparkle

@MainActor
final class UpdateController {
    static let shared = UpdateController()

    let controller: SPUStandardUpdaterController

    private init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func start() {
        controller.startUpdater()
        #if DEBUG
        controller.updater.automaticallyChecksForUpdates = false
        #endif
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
