import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: SettingsStore

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    BrandMark(size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("WallFlow")
                            .font(.headline)
                        Text("Live wallpaper for Mac")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            Section("Playback") {
                Toggle("Mute wallpaper", isOn: $store.isMuted)
                Toggle("Scale to fill", isOn: $store.scaleToFill)
                Text(store.scaleToFill
                     ? "The video is cropped to cover each display."
                     : "The video fits inside each display and may letterbox.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Pause automatically") {
                Toggle("Pause on battery to save power", isOn: $store.pauseOnBattery)
                if store.isOnBattery {
                    Text("Currently running on battery.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Toggle("Pause in Low Power Mode", isOn: $store.pauseOnLowPowerMode)
                Toggle("Pause when an app is fullscreen", isOn: $store.pauseWhenFullscreen)
                Toggle("Pause while using other apps", isOn: $store.pauseWhenUsingOtherApps)
                Text("The wallpaper plays when you can see the desktop, and pauses while you work in another app. It also pauses when the Mac is locked, the displays sleep, or you browse another clip.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Updates") {
                Button("Check for Updates…") {
                    UpdateController.shared.checkForUpdates()
                }
                Text("WallFlow checks GitHub Releases once a day. Turn on automatic install from the Sparkle dialog when an update is offered.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Startup") {
                Toggle("Launch at login", isOn: $store.launchAtLogin)
                if let error = store.launchAtLoginError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .navigationTitle("Settings")
        .onAppear {
            store.syncLaunchAtLoginFromSystem()
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(SettingsStore.shared)
}
