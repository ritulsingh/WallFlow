import SwiftUI

struct HeroDetailView: View {
    @EnvironmentObject private var store: SettingsStore

    var body: some View {
        GeometryReader { geo in
            if let item = store.selectedItem {
                hero(for: item, size: geo.size)
                    .id(item.id)
                    .transition(.opacity)
            } else {
                emptyState
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .background(Color.black)
        .animation(.easeInOut(duration: 0.22), value: store.selectedID)
        .navigationTitle("")
    }

    private func hero(for item: WallpaperItem, size: CGSize) -> some View {
        let isCurrent = store.currentID == item.id

        return ZStack(alignment: .bottom) {
            previewImage(for: item)
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipped()

            if store.isPreviewing && !isCurrent {
                HeroPlayerView(
                    url: item.videoURL,
                    fill: store.scaleToFill,
                    isPlaying: store.isAppActive
                )
                .frame(width: size.width, height: size.height)
                .clipped()
                .allowsHitTesting(false)
            }

            LinearGradient(
                colors: [
                    .black.opacity(0.22),
                    .clear,
                    .clear,
                    .black.opacity(0.55),
                    .black.opacity(0.82)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 18) {
                VStack(spacing: 6) {
                    if isCurrent {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(store.shouldEnginePlay ? Color.green : Color.orange)
                                .frame(width: 6, height: 6)
                            Text(store.shouldEnginePlay ? "Live" : "Paused")
                                .font(.caption.weight(.semibold))
                                .tracking(0.3)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                    }

                    Text(item.prettyName)
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 12, y: 2)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)

                    Text(item.infoLabel)
                        .font(.subheadline.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.72))

                    if !isCurrent, store.currentID != nil {
                        Text("Desktop wallpaper paused while you browse")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                    }

                    if let error = store.videoAccessError {
                        Text(error)
                            .font(.callout)
                            .foregroundStyle(.red)
                    }
                }

                controlBar(for: item, isCurrent: isCurrent)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity)
        }
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private func previewImage(for item: WallpaperItem) -> some View {
        if let image = item.thumbnailImage {
            Image(nsImage: image)
                .resizable()
        } else {
            Color(white: 0.07)
                .overlay {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundStyle(.white.opacity(0.28))
                }
        }
    }

    private func controlBar(for item: WallpaperItem, isCurrent: Bool) -> some View {
        HStack(spacing: 8) {
            if isCurrent {
                Button {
                    store.toggleManualPlayback()
                } label: {
                    Label(
                        store.isManuallyPaused ? "Resume" : "Pause",
                        systemImage: store.isManuallyPaused ? "play.fill" : "pause.fill"
                    )
                }
                .buttonStyle(HUDButtonStyle(prominent: true))
            } else {
                Button {
                    store.togglePreview()
                } label: {
                    Label(
                        store.isPreviewing ? "Stop Preview" : "Preview",
                        systemImage: store.isPreviewing ? "stop.fill" : "play.fill"
                    )
                }
                .buttonStyle(HUDButtonStyle(prominent: false))

                Button {
                    store.setCurrent(item)
                } label: {
                    Label("Set as Wallpaper", systemImage: "desktopcomputer")
                }
                .buttonStyle(HUDButtonStyle(prominent: true))
                .disabled(store.isImporting)
            }

            HUDIconButton(
                systemName: store.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                help: store.isMuted ? "Unmute" : "Mute"
            ) {
                store.isMuted.toggle()
            }

            HUDIconButton(
                systemName: store.scaleToFill ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left",
                help: store.scaleToFill ? "Fit to Display" : "Fill Display"
            ) {
                store.scaleToFill.toggle()
            }

            if isCurrent {
                HUDIconButton(systemName: "stop.fill", help: "Stop Wallpaper") {
                    store.clearVideo()
                }
            }

            HUDIconButton(systemName: "trash", help: "Delete", destructive: true) {
                store.removeFromLibrary(item)
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.25), radius: 18, y: 8)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            BrandMark(size: 108, showName: true, axis: .vertical, nameColor: .white, glow: true)

            Text("Import a short MP4 or MOV to get started.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.62))

            Button("Import Video…") {
                store.chooseVideo()
            }
            .buttonStyle(HUDButtonStyle(prominent: true))
            .padding(.top, 6)
        }
        .padding(32)
    }
}

private struct HUDIconButton: View {
    let systemName: String
    let help: String
    var destructive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 32, height: 32)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(destructive ? Color.red.opacity(0.95) : .white)
        .help(help)
    }
}

private struct HUDButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(.white)
            .background(
                Capsule()
                    .fill(prominent ? Color.accentColor : Color.white.opacity(0.16))
            )
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
