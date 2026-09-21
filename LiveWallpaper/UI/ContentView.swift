import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: SettingsStore
    @Environment(\.openSettings) private var openSettings
    @State private var isDropTargeted = false
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 228, ideal: 268, max: 320)
        } detail: {
            HeroDetailView()
        }
        .searchable(text: $store.searchText, placement: .sidebar, prompt: "Search")
        .frame(minWidth: 860, minHeight: 580)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                BrandMark(showName: true)
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    store.chooseVideo()
                } label: {
                    Image(systemName: "plus")
                }
                .help("Import Video")
                .keyboardShortcut("o", modifiers: .command)

                Button {
                    openSettings()
                } label: {
                    Image(systemName: "gearshape")
                }
                .help("Settings")
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
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.9), lineWidth: 2)
                    .padding(5)
                    .allowsHitTesting(false)
            }
            if store.isImporting {
                ZStack {
                    Color.black.opacity(0.28)
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

    private var selectionBinding: Binding<WallpaperItem.ID?> {
        Binding(
            get: { store.selectedID },
            set: { newValue in
                Task { @MainActor in
                    store.selectedID = newValue
                }
            }
        )
    }

    private var sidebar: some View {
            List(selection: selectionBinding) {
            Section(store.library.count == 1 ? "1 Video" : "\(store.library.count) Videos") {
                ForEach(store.filteredLibrary) { item in
                    SidebarRow(item: item, isCurrent: store.currentID == item.id)
                        .tag(item.id)
                        .onTapGesture(count: 2) {
                            store.setCurrent(item)
                        }
                        .contextMenu {
                            Button("Set as Wallpaper") { store.setCurrent(item) }
                            Divider()
                            Button("Move to Trash", role: .destructive) {
                                store.removeFromLibrary(item)
                            }
                        }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Library")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Divider()
            Button {
                store.chooseVideo()
            } label: {
                Label("Add Video", systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }
}

private struct SidebarRow: View {
    let item: WallpaperItem
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 10) {
            thumbnail
                .frame(width: 52, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
                )

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

            Spacer(minLength: 0)

            if isCurrent {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.tint)
                    .help("Current wallpaper")
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = item.thumbnailImage {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Color.primary.opacity(0.08)
                .overlay {
                    Image(systemName: "film")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(SettingsStore.shared)
}
