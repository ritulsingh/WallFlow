import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: SettingsStore

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gearshape") }

            PlaybackSettingsTab()
                .tabItem { Label("Playback", systemImage: "play.rectangle") }

            PausingSettingsTab()
                .tabItem { Label("Pausing", systemImage: "pause.circle") }

            AboutSettingsTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .onAppear {
            store.syncLaunchAtLoginFromSystem()
        }
    }
}

private struct GeneralSettingsTab: View {
    @EnvironmentObject private var store: SettingsStore

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $store.launchAtLogin)
            } footer: {
                if let error = store.launchAtLoginError {
                    Text(error).foregroundStyle(.red)
                } else {
                    Text("Start WallFlow automatically so your wallpaper is ready when you log in.")
                }
            }

            Section {
                Button("Check for Updates…") {
                    UpdateController.shared.checkForUpdates()
                }
            } header: {
                Text("Updates")
            } footer: {
                Text("WallFlow checks GitHub Releases once a day. Choose automatic install in the update dialog if you’d like updates handled for you.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 340)
    }
}

private struct PlaybackSettingsTab: View {
    @EnvironmentObject private var store: SettingsStore

    var body: some View {
        Form {
            Section {
                Toggle("Mute wallpaper", isOn: $store.isMuted)
                Toggle("Scale to fill", isOn: $store.scaleToFill)
            } footer: {
                Text(store.scaleToFill
                     ? "The video is cropped to cover each display."
                     : "The video fits inside each display and may show black bars.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 230)
    }
}

private struct PausingSettingsTab: View {
    @EnvironmentObject private var store: SettingsStore

    var body: some View {
        Form {
            Section {
                Toggle("Pause on battery", isOn: $store.pauseOnBattery)
                Toggle("Pause in Low Power Mode", isOn: $store.pauseOnLowPowerMode)
            } header: {
                Text("Power")
            } footer: {
                Text(store.isOnBattery
                     ? "This Mac is currently running on battery."
                     : "Save energy by stopping playback when power is limited.")
            }

            Section {
                Toggle("Pause when an app is fullscreen", isOn: $store.pauseWhenFullscreen)
                Toggle("Pause while using other apps", isOn: $store.pauseWhenUsingOtherApps)
            } header: {
                Text("Activity")
            } footer: {
                Text("The wallpaper plays while you can see the desktop. It also pauses when the Mac is locked, the displays sleep, or you browse another clip.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 420)
    }
}

private struct AboutSettingsTab: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String
        if let build, build != short {
            return "Version \(short) (\(build))"
        }
        return "Version \(short)"
    }

    var body: some View {
        VStack(spacing: 14) {
            BrandMark(size: 84, showName: true, axis: .vertical, glow: true)

            VStack(spacing: 4) {
                Text("Live wallpaper for Mac")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(version)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Button("Check for Updates…") {
                UpdateController.shared.checkForUpdates()
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(width: 480, height: 300)
    }
}

#Preview {
    SettingsView()
        .environmentObject(SettingsStore.shared)
}
