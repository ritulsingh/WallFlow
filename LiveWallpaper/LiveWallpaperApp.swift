import SwiftUI

@main
struct LiveWallpaperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = SettingsStore.shared

    var body: some Scene {
        Window("WallFlow", id: "main") {
            ContentView()
                .environmentObject(store)
        }
        .defaultSize(width: 1080, height: 700)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))

        MenuBarExtra {
            StatusMenuView()
                .environmentObject(store)
        } label: {
            Image(systemName: store.menuBarSymbol)
        }

        Settings {
            SettingsView()
                .environmentObject(store)
                .frame(width: 420)
        }
    }
}
