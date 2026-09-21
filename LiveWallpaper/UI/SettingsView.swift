import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: SettingsStore

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gearshape") }

            PlaybackSettingsTab()
                .tabItem { Label("Playback", systemImage: "play.rectangle") }

            RotationSettingsTab()
                .tabItem { Label("Rotation", systemImage: "arrow.triangle.2.circlepath") }

            PerformanceSettingsTab()
                .tabItem { Label("Performance", systemImage: "gauge.with.dots.needle.50percent") }

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
                Toggle("Also set as desktop picture", isOn: $store.setStaticDesktop)
            } header: {
                Text("Desktop")
            } footer: {
                Text("Uses a frame of the video as the macOS desktop picture, so Mission Control, Spaces, and the lock screen match. Your original picture is restored when this is turned off or the wallpaper is removed.")
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
        .frame(width: 500, height: 470)
    }
}

private struct PlaybackSettingsTab: View {
    @EnvironmentObject private var store: SettingsStore

    private static let speeds: [Double] = [0.25, 0.5, 0.75, 1, 1.25, 1.5, 2]

    var body: some View {
        Form {
            Section("Audio") {
                Toggle("Mute wallpaper", isOn: $store.isMuted)
                LabeledContent("Volume") {
                    Slider(value: $store.volume, in: 0...1)
                        .frame(width: 180)
                }
                .disabled(store.isMuted)
            }

            Section {
                Picker("Speed", selection: $store.playbackSpeed) {
                    ForEach(Self.speeds, id: \.self) { speed in
                        Text(label(for: speed)).tag(speed)
                    }
                }
                Toggle("Scale to fill", isOn: $store.scaleToFill)
            } header: {
                Text("Video")
            } footer: {
                Text(store.scaleToFill
                     ? "The video is cropped to cover each display."
                     : "The video fits inside each display and may show black bars.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 350)
    }

    private func label(for speed: Double) -> String {
        (speed == speed.rounded() ? String(format: "%.0f", speed) : String(format: "%g", speed)) + "×"
    }
}

private struct RotationSettingsTab: View {
    @EnvironmentObject private var store: SettingsStore

    private static let intervals: [(minutes: Int, title: String)] = [
        (1, "Every minute"), (5, "Every 5 minutes"), (15, "Every 15 minutes"),
        (30, "Every 30 minutes"), (60, "Every hour"), (180, "Every 3 hours"),
        (720, "Every 12 hours"), (1440, "Every day")
    ]

    var body: some View {
        Form {
            Section {
                Toggle("Rotate wallpapers", isOn: $store.rotationEnabled)
            } footer: {
                Text("Automatically switches to another video in your library. Displays without a wallpaper are left alone.")
            }

            Section {
                Picker("Change", selection: $store.rotationIntervalMinutes) {
                    ForEach(Self.intervals, id: \.minutes) { interval in
                        Text(interval.title).tag(interval.minutes)
                    }
                }

                Picker("Order", selection: $store.rotationShuffle) {
                    Text("Shuffle").tag(true)
                    Text("In order").tag(false)
                }

                Picker("Videos", selection: $store.rotationSourceKey) {
                    Text("All videos").tag(LibraryFilter.all.storageKey)
                    Text("Favorites").tag(LibraryFilter.favorites.storageKey)
                    if !store.collections.isEmpty {
                        Divider()
                        ForEach(store.collections, id: \.self) { name in
                            Text(name).tag(LibraryFilter.collection(name).storageKey)
                        }
                    }
                }
            } header: {
                Text("Schedule")
            } footer: {
                Text("Rotation pauses while playback is paused, the Mac is locked, or the displays are asleep.")
            }
            .disabled(!store.rotationEnabled)

            Section {
                Button("Change Now") {
                    store.rotateWallpaper(force: true)
                }
                .disabled(store.library.count < 2 || !store.hasAnyWallpaper)
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 460)
    }
}

private struct PerformanceSettingsTab: View {
    @EnvironmentObject private var store: SettingsStore

    var body: some View {
        Form {
            Section {
                Picker("Frame rate", selection: $store.frameRateLimit) {
                    Text("Original").tag(0)
                    Text("30 fps").tag(30)
                    Text("24 fps").tag(24)
                    Text("15 fps").tag(15)
                }
            } header: {
                Text("Rendering")
            } footer: {
                Text("A lower frame rate uses less CPU, GPU, and battery. Videos already slower than the limit are unaffected.")
            }

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
        .frame(width: 500, height: 600)
    }
}

private struct AboutSettingsTab: View {
    private static let developer = "ritulsingh"
    private static let repository = URL(string: "https://github.com/ritulsingh/WallFlow")
    private static let issues = URL(string: "https://github.com/ritulsingh/WallFlow/issues")

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String
        if let build, build != short {
            return "Version \(short) (\(build))"
        }
        return "Version \(short)"
    }

    private var year: String {
        String(Calendar.current.component(.year, from: Date()))
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

            Divider()
                .frame(width: 220)
                .padding(.vertical, 2)

            VStack(spacing: 8) {
                (Text("Made with ") + Text(Image(systemName: "heart.fill")).foregroundColor(.pink) + Text(" by \(Self.developer)"))
                    .font(.subheadline)

                HStack(spacing: 18) {
                    if let repository = Self.repository {
                        Link(destination: repository) {
                            Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                        }
                    }
                    if let issues = Self.issues {
                        Link(destination: issues) {
                            Label("Report an Issue", systemImage: "exclamationmark.bubble")
                        }
                    }
                }
                .font(.subheadline)

                Text("© \(year) \(Self.developer). All rights reserved.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(width: 500, height: 400)
    }
}

#Preview {
    SettingsView()
        .environmentObject(SettingsStore.shared)
}
