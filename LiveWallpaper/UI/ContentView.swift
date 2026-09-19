import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: SettingsStore
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 20) {
            header
            dropZone
            if store.videoURL != nil {
                playbackRow
            }
            if let error = store.videoAccessError {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            hint
        }
        .padding(28)
        .frame(minWidth: 480, minHeight: 400)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted, perform: handleDrop)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Image(systemName: "sparkles.tv")
                .font(.system(size: 36))
                .foregroundStyle(.tint)
            Text("Live Wallpaper")
                .font(.title2.weight(.semibold))
            Text("Loop a short video behind your desktop icons.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var dropZone: some View {
        VStack(spacing: 12) {
            Image(systemName: store.videoURL == nil ? "film" : "checkmark.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(store.videoURL == nil ? .secondary : Color.accentColor)
            if let name = store.videoURL?.lastPathComponent ?? optionalName {
                Text(name)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                if let duration = store.videoDuration {
                    Text(durationLabel(duration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Drop an MP4 or MOV here")
                    .font(.headline)
                Text("or choose a file")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button("Choose Video…") {
                    store.chooseVideo()
                }
                .keyboardShortcut("o", modifiers: .command)
                if store.videoURL != nil {
                    Button("Remove") {
                        store.clearVideo()
                    }
                }
            }
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.quaternary.opacity(isDropTargeted ? 0.9 : 0.45))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.25),
                    style: StrokeStyle(lineWidth: 1.5, dash: isDropTargeted ? [] : [6, 4])
                )
        )
    }

    private var playbackRow: some View {
        HStack {
            Button {
                store.toggleManualPlayback()
            } label: {
                Label(
                    store.isManuallyPaused ? "Play Wallpaper" : "Pause Wallpaper",
                    systemImage: store.isManuallyPaused ? "play.fill" : "pause.fill"
                )
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()

            statusCaption
        }
    }

    private var statusCaption: some View {
        Text(statusText)
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.trailing)
    }

    private var hint: some View {
        Text("Best results: 5–15 second muted H.264 or HEVC clips whose first and last frames match.")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
    }

    private var optionalName: String? {
        store.videoDisplayName.isEmpty ? nil : store.videoDisplayName
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

    private func durationLabel(_ seconds: TimeInterval) -> String {
        let rounded = Int(seconds.rounded())
        return "\(rounded)s clip"
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url: URL?
            if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else if let dropped = item as? URL {
                url = dropped
            } else {
                url = nil
            }
            guard let url else { return }
            Task { @MainActor in
                store.setVideo(url: url)
            }
        }
        return true
    }
}

#Preview {
    ContentView()
        .environmentObject(SettingsStore.shared)
}
