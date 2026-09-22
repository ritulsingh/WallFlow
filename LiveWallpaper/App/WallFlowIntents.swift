import AppIntents
import Foundation

struct WallpaperEntity: AppEntity {
    let id: UUID
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "WallFlow Video"
    static var defaultQuery = WallpaperEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct WallpaperEntityQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [WallpaperEntity.ID]) async throws -> [WallpaperEntity] {
        SettingsStore.shared.library
            .filter { identifiers.contains($0.id) }
            .map { WallpaperEntity(id: $0.id, name: $0.prettyName) }
    }

    @MainActor
    func suggestedEntities() async throws -> [WallpaperEntity] {
        SettingsStore.shared.library
            .sorted { $0.addedAt > $1.addedAt }
            .map { WallpaperEntity(id: $0.id, name: $0.prettyName) }
    }
}

struct SetWallpaperIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Wallpaper"
    static var description = IntentDescription("Sets a video from your WallFlow library as your desktop wallpaper.")

    @Parameter(title: "Video")
    var video: WallpaperEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let item = SettingsStore.shared.library.first(where: { $0.id == video.id }) else {
            return .result(dialog: "WallFlow couldn't find that video anymore.")
        }
        SettingsStore.shared.setCurrent(item)
        return .result(dialog: "Set \(item.prettyName) as your wallpaper.")
    }
}

struct NextWallpaperIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Wallpaper"
    static var description = IntentDescription("Switches WallFlow to the next wallpaper in your library.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = SettingsStore.shared
        guard store.hasAnyWallpaper else {
            return .result(dialog: "WallFlow doesn't have a wallpaper set yet.")
        }
        guard store.library.count > 1 else {
            return .result(dialog: "WallFlow needs at least two videos in your library to switch.")
        }
        store.rotateWallpaper(force: true)
        return .result(dialog: "Switched to \(store.currentItem?.prettyName ?? "the next video").")
    }
}

struct ToggleWallpaperIntent: AppIntent {
    static var title: LocalizedStringResource = "Pause or Resume Wallpaper"
    static var description = IntentDescription("Pauses or resumes the WallFlow wallpaper.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = SettingsStore.shared
        guard store.hasAnyWallpaper else {
            return .result(dialog: "WallFlow doesn't have a wallpaper set yet.")
        }
        store.toggleManualPlayback()
        return .result(dialog: store.isManuallyPaused ? "Paused your wallpaper." : "Resumed your wallpaper.")
    }
}

struct WallFlowShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SetWallpaperIntent(),
            phrases: [
                "Set my wallpaper to \(\.$video) in \(.applicationName)",
                "Change wallpaper to \(\.$video) in \(.applicationName)"
            ],
            shortTitle: "Set Wallpaper",
            systemImageName: "photo.on.rectangle"
        )
        AppShortcut(
            intent: NextWallpaperIntent(),
            phrases: [
                "Next wallpaper in \(.applicationName)",
                "Switch my wallpaper in \(.applicationName)"
            ],
            shortTitle: "Next Wallpaper",
            systemImageName: "forward.fill"
        )
        AppShortcut(
            intent: ToggleWallpaperIntent(),
            phrases: [
                "Pause my wallpaper in \(.applicationName)",
                "Toggle my wallpaper in \(.applicationName)"
            ],
            shortTitle: "Pause or Resume Wallpaper",
            systemImageName: "pause.fill"
        )
    }
}
