import SwiftUI

struct StatusMenuView: View {
    @EnvironmentObject private var store: SettingsStore
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        BrandMark(size: 18, showName: true)

        Divider()

        if store.connectedDisplays.count > 1 {
            ForEach(store.connectedDisplays) { display in
                Text("\(display.name): \(store.wallpaperItem(for: display.id)?.prettyName ?? "None")")
            }
        } else {
            Text(store.currentItem?.prettyName ?? "No Wallpaper")
        }

        Divider()

        Button(store.isManuallyPaused ? "Play" : "Pause") {
            store.toggleManualPlayback()
        }
        .disabled(!store.hasAnyWallpaper)
        .keyboardShortcut("p")

        Button("Import Video…") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
            store.chooseVideo()
        }

        if store.hasAnyWallpaper {
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

        Button("Check for Updates…") {
            UpdateController.shared.checkForUpdates()
        }

        Divider()

        Button("Quit WallFlow") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
