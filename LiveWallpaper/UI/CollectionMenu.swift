import SwiftUI

struct CollectionMenu: View {
    @EnvironmentObject private var store: SettingsStore
    let item: WallpaperItem

    @State private var isNaming = false
    @State private var newName = ""

    var body: some View {
        Menu {
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
                newName = ""
                isNaming = true
            }

            if item.collection != nil {
                Button("Remove from Collection") {
                    store.setCollection(nil, for: item)
                }
            }
        } label: {
            Text(item.collection ?? "None")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .alert("New Collection", isPresented: $isNaming) {
            TextField("Name", text: $newName)
            Button("Create") {
                store.setCollection(newName, for: item)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("“\(item.prettyName)” will be added to this collection.")
        }
    }
}
