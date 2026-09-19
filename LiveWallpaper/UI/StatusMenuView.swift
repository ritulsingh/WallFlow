import SwiftUI

struct StatusMenuView: View {
    @EnvironmentObject private var store: SettingsStore
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Text(store.videoDisplayName.isEmpty ? "No wallpaper selected" : store.videoDisplayName)

        Divider()

        Button(store.isManuallyPaused ? "Play" : "Pause") {
            store.toggleManualPlayback()
        }
        .disabled(store.videoURL == nil)
        .keyboardShortcut("p")

        Button("Choose Video…") {
            store.chooseVideo()
        }

        if store.videoURL != nil {
            Button("Remove Wallpaper") {
                store.clearVideo()
            }
        }

        Divider()

        Button("Open WallFlow") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }

        Button("Settings…") {
            openSettings()
            NSApp.activate(ignoringOtherApps: true)
        }

        Divider()

        Button("Quit WallFlow") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
