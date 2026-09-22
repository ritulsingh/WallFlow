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
                Menu {
                    Button("Import from File…") {
                        store.chooseVideo()
                    }
                    .keyboardShortcut("o", modifiers: .command)

                    Button("Import from URL…") {
                        store.isShowingURLImporter = true
                    }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                } label: {
                    Label("Import Video", systemImage: "plus")
                }
                .menuIndicator(.hidden)
                .help("Import Video")

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
        .sheet(isPresented: $store.isShowingURLImporter) {
            URLImportSheet()
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
                Text("Drop a short MP4, MOV, GIF, or WebM here, or choose one from your Mac.")
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

            Button("Import from URL…") {
                store.isShowingURLImporter = true
            }
            .buttonStyle(.link)

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
            filterChips

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

            Text(countLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Menu {
                Picker("Sort By", selection: $store.librarySort) {
                    ForEach(LibrarySort.allCases) { sort in
                        Text(sort.title).tag(sort)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
                    .labelStyle(.iconOnly)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Sort by \(store.librarySort.title)")
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var countLabel: String {
        let shown = store.filteredLibrary.count
        let total = store.library.count
        if shown == total {
            return total == 1 ? "1 video" : "\(total) videos"
        }
        return "\(shown) of \(total)"
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", systemImage: "square.grid.2x2", filter: .all)
                FilterChip(title: "Favorites", systemImage: "heart.fill", filter: .favorites)
                ForEach(store.collections, id: \.self) { name in
                    FilterChip(title: name, systemImage: "folder", filter: .collection(name))
                }
            }
            .padding(.horizontal, 22)
        }
        .padding(.bottom, 10)
    }
}

private struct FilterChip: View {
    @EnvironmentObject private var store: SettingsStore
    let title: String
    let systemImage: String
    let filter: LibraryFilter

    var body: some View {
        let isActive = store.activeFilter == filter
        Button {
            store.libraryFilter = filter
        } label: {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .foregroundStyle(isActive ? Color.white : Color.primary)
                .background(
                    Capsule().fill(isActive ? Color.accentColor : Color.primary.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? .isSelected : [])
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
    @State private var isNamingCollection = false
    @State private var newCollectionName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Color.clear
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay { thumbnail }
                .overlay(alignment: .bottomLeading) {
                    if isCurrent {
                        StatusPill(text: store.assignmentLabel(for: item) ?? "Current", color: .green)
                            .frame(maxWidth: 160, alignment: .leading)
                            .padding(8)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if item.isFavorite || isHovering {
                        Button {
                            store.toggleFavorite(item)
                        } label: {
                            Image(systemName: item.isFavorite ? "heart.fill" : "heart")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(item.isFavorite ? Color.pink : Color.white)
                                .frame(width: 26, height: 26)
                                .background(.black.opacity(0.5), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(7)
                        .help(item.isFavorite ? "Remove from Favorites" : "Add to Favorites")
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
            Button(item.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
                store.toggleFavorite(item)
            }
            Menu("Collection") {
                ForEach(store.collections, id: \.self) { name in
                    Button {
                        store.setCollection(name, for: item)
                    } label: {
                        if item.collection == name {
                            Label(name, systemImage: "checkmark")
                        } else {
                            Text(name)
                        }
                    }
                }
                if !store.collections.isEmpty {
                    Divider()
                }
                Button("New Collection…") {
                    newCollectionName = ""
                    isNamingCollection = true
                }
                if item.collection != nil {
                    Button("Remove from Collection") {
                        store.setCollection(nil, for: item)
                    }
                }
            }
            Divider()
            Button("Move to Trash", role: .destructive) {
                store.removeFromLibrary(item)
            }
        }
        .alert("New Collection", isPresented: $isNamingCollection) {
            TextField("Name", text: $newCollectionName)
            Button("Create") {
                store.setCollection(newCollectionName, for: item)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("“\(item.prettyName)” will be added to this collection.")
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

            if store.hasAnyWallpaper, store.library.count > 1 {
                Button {
                    store.rotateWallpaper(force: true)
                } label: {
                    Label("Next", systemImage: "forward.fill")
                }
                .controlSize(.regular)
                .help("Switch to the next wallpaper")
            }

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
