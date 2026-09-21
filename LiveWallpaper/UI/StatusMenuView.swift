import SwiftUI

struct StatusMenuView: View {
    @EnvironmentObject private var store: SettingsStore
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(12)

            Divider()

            VStack(spacing: 2) {
                MenuRow(
                    title: store.isManuallyPaused ? "Play" : "Pause",
                    systemImage: store.isManuallyPaused ? "play.fill" : "pause.fill",
                    isEnabled: store.hasAnyWallpaper
                ) {
                    store.toggleManualPlayback()
                }

                MenuRow(
                    title: "Next Wallpaper",
                    systemImage: "forward.fill",
                    isEnabled: store.hasAnyWallpaper && store.library.count > 1
                ) {
                    store.rotateWallpaper(force: true)
                }

                MenuRow(title: "Import Video…", systemImage: "plus") {
                    showMainWindow()
                    store.chooseVideo()
                }

                if store.hasAnyWallpaper {
                    MenuRow(title: "Remove Wallpaper", systemImage: "stop.fill") {
                        store.clearVideo()
                    }
                }
            }
            .padding(6)

            Divider()

            VStack(spacing: 2) {
                MenuRow(title: "Open WallFlow", systemImage: "macwindow") {
                    showMainWindow()
                }
                MenuRow(title: "Settings…", systemImage: "gearshape") {
                    openSettings()
                    NSApp.activate(ignoringOtherApps: true)
                }
                MenuRow(title: "Check for Updates…", systemImage: "arrow.triangle.2.circlepath") {
                    UpdateController.shared.checkForUpdates()
                }
            }
            .padding(6)

            Divider()

            MenuRow(title: "Quit WallFlow", systemImage: "power") {
                NSApp.terminate(nil)
            }
            .padding(6)
        }
        .frame(width: 290)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            BrandMark(size: 20, showName: true)

            HStack(spacing: 12) {
                thumbnail
                    .frame(width: 84, height: 47)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(WallFlowTheme.hairline, lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(currentTitle)
                        .font(Font.headline)
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)

                    if store.hasAnyWallpaper {
                        StatusPill(
                            text: store.shouldEnginePlay ? "Live" : "Paused",
                            color: store.shouldEnginePlay ? .green : .orange
                        )
                    } else {
                        Text("Nothing playing")
                            .font(Font.caption)
                            .foregroundStyle(Color.secondary)
                    }
                }
                Spacer(minLength: 0)
            }

            if store.connectedDisplays.count > 1 {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(store.connectedDisplays) { display in
                        HStack {
                            Text(display.name)
                                .foregroundStyle(Color.secondary)
                            Spacer(minLength: 8)
                            Text(store.wallpaperItem(for: display.id)?.prettyName ?? "None")
                                .foregroundStyle(Color.primary)
                                .lineLimit(1)
                        }
                        .font(Font.caption)
                    }
                }
            }
        }
    }

    private var currentTitle: String {
        store.currentItem?.prettyName ?? "No Wallpaper"
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = store.currentItem?.thumbnailImage {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Color.secondary.opacity(0.15)
                .overlay {
                    Image(systemName: "play.rectangle")
                        .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                }
        }
    }

    private func showMainWindow() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct MenuRow: View {
    let title: String
    let systemImage: String
    var isEnabled = true
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 18)
                Text(title)
                    .font(Font.subheadline.weight(.medium))
                Spacer(minLength: 0)
            }
            .foregroundStyle(Color.primary.opacity(isEnabled ? 1 : 0.4))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(isHovering && isEnabled ? 0.09 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { isHovering = $0 }
    }
}
