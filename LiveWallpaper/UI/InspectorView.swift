import SwiftUI

struct InspectorView: View {
    @EnvironmentObject private var store: SettingsStore

    var body: some View {
        if let item = store.selectedItem {
            details(for: item)
                .id(item.id)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "rectangle.dashed")
                    .font(.system(size: 30))
                    .foregroundStyle(.tertiary)
                Text("Select a video")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func details(for item: WallpaperItem) -> some View {
        let isCurrent = store.isAssigned(item.id)

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                preview(for: item, isCurrent: isCurrent)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.prettyName)
                        .font(.title2.weight(.semibold))
                        .lineLimit(2)
                    Text(item.infoLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Text(assignmentText(for: item, isCurrent: isCurrent))
                        .font(.subheadline)
                        .foregroundStyle(isCurrent ? Color.accentColor : Color.secondary)
                }

                if let error = store.videoAccessError {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                }

                actions(for: item, isCurrent: isCurrent)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Playback")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    VStack(spacing: 0) {
                        toggleRow("Mute", isOn: $store.isMuted)
                        Divider()
                        toggleRow("Scale to fill", isOn: $store.scaleToFill)
                    }
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(WallFlowTheme.hairline, lineWidth: 1)
                    )
                }

                Button(role: .destructive) {
                    store.removeFromLibrary(item)
                } label: {
                    Label("Move to Trash", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.red)
                }
                .controlSize(.large)
            }
            .padding(16)
        }
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: 8)
            Toggle(title, isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.vertical, 9)
    }

    private func assignmentText(for item: WallpaperItem, isCurrent: Bool) -> String {
        if let label = store.assignmentLabel(for: item) {
            return "Playing on \(label)"
        }
        return store.hasAnyWallpaper ? "Not set · desktop paused while you browse" : "Not set as wallpaper"
    }

    private func preview(for item: WallpaperItem, isCurrent: Bool) -> some View {
        Color.clear
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                ZStack {
                    if let image = item.thumbnailImage {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.secondary.opacity(0.15)
                            .overlay {
                                Image(systemName: "film")
                                    .font(.title2)
                                    .foregroundStyle(.tertiary)
                            }
                    }

                    if store.isPreviewing && !isCurrent {
                        HeroPlayerView(
                            url: item.videoURL,
                            fill: store.scaleToFill,
                            isPlaying: store.isAppActive
                        )
                        .allowsHitTesting(false)
                    }
                }
            }
            .overlay(alignment: .topLeading) {
                if isCurrent {
                    StatusPill(
                        text: store.shouldEnginePlay ? "Live" : "Paused",
                        color: store.shouldEnginePlay ? .green : .orange
                    )
                    .padding(8)
                } else if store.isPreviewing {
                    StatusPill(text: "Previewing", color: .accentColor)
                        .padding(8)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: WallFlowTheme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: WallFlowTheme.cardRadius, style: .continuous)
                    .strokeBorder(WallFlowTheme.hairline, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
    }

    @ViewBuilder
    private func actions(for item: WallpaperItem, isCurrent: Bool) -> some View {
        VStack(spacing: 8) {
            setWallpaperControl(for: item)

            HStack(spacing: 8) {
                if isCurrent {
                    Button {
                        store.toggleManualPlayback()
                    } label: {
                        Label(
                            store.isManuallyPaused ? "Resume" : "Pause",
                            systemImage: store.isManuallyPaused ? "play.fill" : "pause.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }

                    Button {
                        store.removeAssignment(for: item)
                    } label: {
                        Label("Remove", systemImage: "xmark")
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    Button {
                        store.togglePreview()
                    } label: {
                        Label(
                            store.isPreviewing ? "Stop Preview" : "Preview",
                            systemImage: store.isPreviewing ? "stop.fill" : "play.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .controlSize(.large)
        }
    }

    @ViewBuilder
    private func setWallpaperControl(for item: WallpaperItem) -> some View {
        let displays = store.connectedDisplays
        if displays.count <= 1 {
            Button {
                store.setCurrent(item)
            } label: {
                Label("Set as Wallpaper", systemImage: "desktopcomputer")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(store.isImporting)
        } else {
            Menu {
                Button("All Displays") {
                    store.setCurrent(item)
                }
                Divider()
                ForEach(displays) { display in
                    Button {
                        store.setCurrent(item, displayIDs: [display.id])
                    } label: {
                        if store.wallpaperID(for: display.id) == item.id {
                            Label(display.name, systemImage: "checkmark")
                        } else {
                            Text(display.name)
                        }
                    }
                }
            } label: {
                Label("Set as Wallpaper", systemImage: "desktopcomputer")
                    .frame(maxWidth: .infinity)
            }
            .menuStyle(.button)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(store.isImporting)
        }
    }
}
