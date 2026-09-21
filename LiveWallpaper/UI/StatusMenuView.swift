import SwiftUI

struct StatusMenuView: View {
    @EnvironmentObject private var store: SettingsStore
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        BrandMark(size: 18, showName: true)

        Divider()

        Text(store.currentItem?.prettyName ?? "No Wallpaper")

        Divider()

        Button(store.isManuallyPaused ? "Play" : "Pause") {
            store.toggleManualPlayback()
        }
        .disabled(store.videoURL == nil)
        .keyboardShortcut("p")

        Button("Import Video…") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
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
