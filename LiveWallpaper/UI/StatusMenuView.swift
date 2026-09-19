import SwiftUI

struct StatusMenuView: View {
    @EnvironmentObject private var store: SettingsStore
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        HStack(spacing: 8) {
            Image("Logo")
                .resizable()
                .scaledToFill()
                .frame(width: 18, height: 18)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            Text("WallFlow")
        }

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
