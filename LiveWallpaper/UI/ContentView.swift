import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: SettingsStore
    @Environment(\.openSettings) private var openSettings
    @State private var isDropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            dropController
            playbackControls
            if let error = store.videoAccessError {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
            Text("Drop a short MP4 or MOV here. WallFlow loops it behind your desktop icons.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 520)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("WallFlow")
                    .font(.title2.weight(.semibold))
                Text("Wallpaper controller")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .help("Settings")
        }
    }

    private var dropController: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.black.opacity(0.88))

            if let url = store.videoURL {
                WallpaperPreviewView(
                    url: url,
                    fill: store.scaleToFill,
                    isPlaying: store.shouldEnginePlay
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            VideoDropCatcher(isTargeted: $isDropTargeted) { url in
                store.setVideo(url: url)
            }

            VStack(spacing: 10) {
                if store.videoURL == nil {
                    Image(systemName: "arrow.down.app")
                        .font(.system(size: 32, weight: .medium))
                    Text("Drag a video here")
                        .font(.headline)
                    Text("MP4, MOV, or M4V")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                } else {
                    Spacer()
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.videoDisplayName)
                                .font(.headline)
                                .lineLimit(1)
                            Text(previewCaption)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.75))
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .foregroundStyle(.white)
            .padding(20)
            .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, minHeight: 280)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    isDropTargeted ? Color.accentColor : Color.white.opacity(0.18),
                    style: StrokeStyle(lineWidth: isDropTargeted ? 3 : 1, dash: isDropTargeted ? [] : [7, 5])
                )
        )
        .scaleEffect(isDropTargeted ? 1.015 : 1)
        .animation(.easeOut(duration: 0.15), value: isDropTargeted)
    }

    private var playbackControls: some View {
        HStack(spacing: 10) {
            if store.videoURL != nil {
                Button {
                    store.toggleManualPlayback()
                } label: {
                    Label(
                        store.isManuallyPaused ? "Play on Desktop" : "Pause Desktop",
                        systemImage: store.isManuallyPaused ? "play.fill" : "pause.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            Button("Choose Video…") {
                store.chooseVideo()
            }
            .keyboardShortcut("o", modifiers: .command)
            .controlSize(.large)

            if store.videoURL != nil {
                Button("Remove") {
                    store.clearVideo()
                }
                .controlSize(.large)
            }

            Spacer()

            if store.videoURL != nil {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private var previewCaption: String {
        if let duration = store.videoDuration {
            return "\(Int(duration.rounded()))s clip · preview of your desktop wallpaper"
        }
        return "Preview of your desktop wallpaper"
    }

    private var statusText: String {
        if store.isScreenLocked {
            return "Paused while the screen is locked"
        }
        if store.isDisplayAsleep {
            return "Paused while displays are asleep"
        }
        if store.pauseOnLowPowerMode && store.isLowPowerMode {
            return "Paused in Low Power Mode"
        }
        if store.pauseOnBattery && store.isOnBattery {
            return "Paused on battery"
        }
        if store.isManuallyPaused {
            return "Paused"
        }
        return store.shouldEnginePlay ? "Playing on the desktop" : "Paused"
    }
}

#Preview {
    ContentView()
        .environmentObject(SettingsStore.shared)
}
