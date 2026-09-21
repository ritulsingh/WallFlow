import Foundation

enum LibrarySort: String, CaseIterable, Identifiable {
    case recent
    case name
    case duration
    case resolution

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recent: return "Date Added"
        case .name: return "Name"
        case .duration: return "Duration"
        case .resolution: return "Resolution"
        }
    }

    func areInIncreasingOrder(_ a: WallpaperItem, _ b: WallpaperItem) -> Bool {
        switch self {
        case .recent:
            return a.addedAt > b.addedAt
        case .name:
            return a.prettyName.localizedStandardCompare(b.prettyName) == .orderedAscending
        case .duration:
            return (a.duration ?? 0) > (b.duration ?? 0)
        case .resolution:
            return a.pixelCount > b.pixelCount
        }
    }
}

enum LibraryFilter: Hashable {
    case all
    case favorites
    case collection(String)

    private static let collectionPrefix = "collection:"

    var storageKey: String {
        switch self {
        case .all: return "all"
        case .favorites: return "favorites"
        case .collection(let name): return Self.collectionPrefix + name
        }
    }

    init(storageKey: String) {
        if storageKey == "favorites" {
            self = .favorites
        } else if storageKey.hasPrefix(Self.collectionPrefix) {
            self = .collection(String(storageKey.dropFirst(Self.collectionPrefix.count)))
        } else {
            self = .all
        }
    }

    func matches(_ item: WallpaperItem) -> Bool {
        switch self {
        case .all: return true
        case .favorites: return item.isFavorite
        case .collection(let name): return item.collection == name
        }
    }
}
