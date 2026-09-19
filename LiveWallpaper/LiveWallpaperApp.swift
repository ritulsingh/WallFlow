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
        .defaultSize(width: 520, height: 460)
        .windowResizability(.contentSize)

        MenuBarExtra {
            StatusMenuView()
                .environmentObject(store)
        } label: {
            Image(systemName: store.menuBarSymbol)
        }

        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }
}
