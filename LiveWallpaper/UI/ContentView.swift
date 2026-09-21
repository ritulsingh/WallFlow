import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: SettingsStore
    @Environment(\.openSettings) private var openSettings
    @State private var isDropTargeted = false
    @State private var isInspectorShown = true

    var body: some View {
        VStack(spacing: 0) {
            if store.library.isEmpty {
                EmptyLibraryView()
            } else {
                LibraryGrid()
            }
            Divider()
            NowPlayingBar()
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .inspector(isPresented: inspectorBinding) {
            InspectorView()
                .inspectorColumnWidth(min: 280, ideal: 320, max: 400)
        }
        .frame(minWidth: 900, minHeight: 600)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                BrandMark(showName: true)
                    .padding(.horizontal, 10)
                    .fixedSize()
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    store.chooseVideo()
                } label: {
                    Label("Import Video", systemImage: "plus")
                }
                .help("Import Video")
                .keyboardShortcut("o", modifiers: .command)

                Button {
                    openSettings()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .help("Settings")

                if !store.library.isEmpty {
                    Button {
                        isInspectorShown.toggle()
                    } label: {
                        Label("Details", systemImage: "sidebar.trailing")
                    }
                    .help("Show or Hide Details")
                }
            }
        }
        .onAppear {
            store.syncLaunchAtLoginFromSystem()
        }
        .fileImporter(
            isPresented: $store.isShowingImporter,
            allowedContentTypes: SettingsStore.allowedVideoTypes,
            allowsMultipleSelection: true
        ) { result in
            store.importVideos(from: result)
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: WallFlowTheme.cardRadius, style: .continuous)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2.5, dash: [8, 6]))
                    .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: WallFlowTheme.cardRadius, style: .continuous))
                    .padding(8)
                    .allowsHitTesting(false)
            }
            if store.isImporting {
                ZStack {
                    Color.black.opacity(0.25)
                    ProgressView("Importing…")
                        .padding(.horizontal, 22)
                        .padding(.vertical, 18)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .background {
            VideoDropCatcher(isTargeted: $isDropTargeted) { url in
                store.importDropped(url: url)
            }
        }
    }

    private var inspectorBinding: Binding<Bool> {
        Binding(
            get: { isInspectorShown && !store.library.isEmpty },
            set: { isInspectorShown = $0 }
        )
    }
}

private struct EmptyLibraryView: View {
    @EnvironmentObject private var store: SettingsStore

    var body: some View {
        VStack(spacing: 16) {
            BrandMark(size: 96, showName: true, axis: .vertical, glow: true)

            VStack(spacing: 6) {
                Text("Bring your desktop to life")
                    .font(.title3.weight(.semibold))
                Text("Drop a short MP4, MOV, or M4V here, or choose one from your Mac.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                store.chooseVideo()
            } label: {
                Label("Import Video", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if let error = store.videoAccessError {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        }
        .padding(40)
        .frame(maxWidth: 520)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.14), style: StrokeStyle(lineWidth: 1.5, dash: [8, 7]))
        )
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct LibraryGrid: View {
    @EnvironmentObject private var store: SettingsStore

    private let columns = [GridItem(.adaptive(minimum: 190, maximum: 280), spacing: 18)]

    var body: some View {
        VStack(spacing: 0) {
            filterBar

            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 22) {
                    AddClipCard()

                    ForEach(store.filteredLibrary) { item in
                        ClipCard(
                            item: item,
                            isSelected: store.selectedID == item.id,
                            isCurrent: store.isAssigned(item.id)
                        )
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 22)
                .padding(.top, 6)
            }
            .overlay {
                if store.filteredLibrary.isEmpty {
                    Text("No videos match “\(store.searchText)”")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var filterBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search videos", text: $store.searchText)
                    .textFieldStyle(.plain)
                if !store.searchText.isEmpty {
                    Button {
                        store.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear Search")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: 260)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(WallFlowTheme.hairline, lineWidth: 1)
            )

            Spacer(minLength: 0)

            Text(store.library.count == 1 ? "1 video" : "\(store.library.count) videos")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }
}

private struct AddClipCard: View {
    @EnvironmentObject private var store: SettingsStore
    @State private var isHovering = false

    var body: some View {
        Button {
            store.chooseVideo()
        } label: {
            Color.clear
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay {
                    VStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .medium))
                        Text("Add Video")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(isHovering ? Color.primary : Color.secondary)
                }
                .background(
                    RoundedRectangle(cornerRadius: WallFlowTheme.cardRadius, style: .continuous)
                        .fill(Color.primary.opacity(isHovering ? 0.06 : 0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: WallFlowTheme.cardRadius, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.18), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .frame(maxHeight: .infinity, alignment: .top)
        .help("Import Video")
    }
}

private struct ClipCard: View {
    @EnvironmentObject private var store: SettingsStore
    let item: WallpaperItem
    let isSelected: Bool
    let isCurrent: Bool
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Color.clear
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay { thumbnail }
                .overlay(alignment: .bottomLeading) {
                    if isCurrent {
                        StatusPill(text: "Current", color: .green)
                            .padding(8)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: WallFlowTheme.cardRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: WallFlowTheme.cardRadius, style: .continuous)
                        .strokeBorder(
                            isSelected ? Color.accentColor : WallFlowTheme.hairline,
                            lineWidth: isSelected ? 3 : 1
                        )
                )
                .shadow(color: .black.opacity(isHovering ? 0.28 : 0.14), radius: isHovering ? 12 : 6, y: 3)
                .scaleEffect(isHovering ? 1.02 : 1)
                .animation(.easeOut(duration: 0.14), value: isHovering)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.prettyName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(item.infoLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture(count: 2) {
            store.setCurrent(item)
        }
        .onTapGesture {
            store.selectedID = item.id
        }
        .contextMenu {
            if store.connectedDisplays.count > 1 {
                Button("Set on All Displays") { store.setCurrent(item) }
                ForEach(store.connectedDisplays) { display in
                    Button("Set on \(display.name)") {
                        store.setCurrent(item, displayIDs: [display.id])
                    }
                }
            } else {
                Button("Set as Wallpaper") { store.setCurrent(item) }
            }
            Divider()
            Button("Move to Trash", role: .destructive) {
                store.removeFromLibrary(item)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.prettyName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = item.thumbnailImage {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Color.secondary.opacity(0.15)
                .overlay {
                    Image(systemName: "film")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                }
        }
    }
}

private struct NowPlayingBar: View {
    @EnvironmentObject private var store: SettingsStore

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
                .frame(width: 48, height: 27)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(WallFlowTheme.hairline, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(store.currentItem?.prettyName ?? "No wallpaper set")
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if store.hasAnyWallpaper {
                Button {
                    store.toggleManualPlayback()
                } label: {
                    Label(
                        store.isManuallyPaused ? "Resume" : "Pause",
                        systemImage: store.isManuallyPaused ? "play.fill" : "pause.fill"
                    )
                }
                .controlSize(.regular)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var subtitle: String {
        guard let item = store.currentItem else {
            return "Double-click a video to set it as your wallpaper"
        }
        let state = store.shouldEnginePlay ? "Live" : "Paused"
        if let label = store.assignmentLabel(for: item) {
            return "\(state) · \(label)"
        }
        return state
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
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(SettingsStore.shared)
}
