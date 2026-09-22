import AppKit
import AVFoundation
import Foundation

struct WallpaperItem: Identifiable, Codable, Hashable {
    let id: UUID
    var displayName: String
    var fileName: String
    var thumbnailName: String?
    var duration: TimeInterval?
    var pixelWidth: Int?
    var pixelHeight: Int?
    var addedAt: Date
    var favorite: Bool?
    var collection: String?
    var loopMismatch: Bool?

    var isFavorite: Bool { favorite ?? false }

    var pixelCount: Int { (pixelWidth ?? 0) * (pixelHeight ?? 0) }

    var videoURL: URL {
        WallpaperLibrary.videosDirectory.appendingPathComponent(fileName)
    }

    var thumbnailURL: URL? {
        guard let thumbnailName else { return nil }
        return WallpaperLibrary.thumbsDirectory.appendingPathComponent(thumbnailName)
    }

    var thumbnailImage: NSImage? {
        guard let thumbnailURL else { return nil }
        return ThumbnailCache.shared.image(for: thumbnailURL)
    }

    var prettyName: String {
        let cleaned = displayName
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: ".com", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let words = cleaned.split(separator: " ")
        // "valley-misty-moewalls-com" is a downloaded-from-site filename; drop the "<site> com" tail.
        if words.count > 3, words.last?.lowercased() == "com" {
            return words.dropLast(2).map { $0.localizedCapitalized }.joined(separator: " ")
        }
        let titled = cleaned
            .split(separator: " ")
            .map { $0.localizedCapitalized }
            .joined(separator: " ")
        return titled.isEmpty ? displayName : titled
    }

    var infoLabel: String {
        var parts: [String] = []
        if let duration {
            parts.append("\(Int(duration.rounded()))s")
        }
        if let pixelWidth, let pixelHeight {
            parts.append("\(pixelWidth)×\(pixelHeight)")
        }
        return parts.isEmpty ? "Imported video" : parts.joined(separator: "  ·  ")
    }
}

/// Decoded thumbnails are reused across SwiftUI re-renders (e.g. hover state changes)
/// instead of re-reading and re-decoding the JPEG from disk on every access.
final class ThumbnailCache {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSURL, NSImage>()

    private init() {}

    func image(for url: URL) -> NSImage? {
        let key = url as NSURL
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let image = NSImage(contentsOf: url) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}

enum WallpaperLibrary {
    static var rootDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let root = base.appendingPathComponent("WallFlow", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    static var videosDirectory: URL {
        let url = rootDirectory.appendingPathComponent("Library", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static var thumbsDirectory: URL {
        let url = rootDirectory.appendingPathComponent("Thumbs", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static var catalogURL: URL {
        rootDirectory.appendingPathComponent("library.json")
    }

    static func load() -> [WallpaperItem] {
        guard let data = try? Data(contentsOf: catalogURL),
              let items = try? JSONDecoder().decode([WallpaperItem].self, from: data)
        else {
            return []
        }
        return items.filter { FileManager.default.fileExists(atPath: $0.videoURL.path) }
    }

    static func save(_ items: [WallpaperItem]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: catalogURL, options: .atomic)
    }

    static func isSupportedVideo(_ url: URL) -> Bool {
        MediaConverter.supportedExtensions.contains(url.pathExtension.lowercased())
    }

    static func importVideo(from source: URL) throws -> WallpaperItem {
        let accessed = source.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                source.stopAccessingSecurityScopedResource()
            }
        }

        guard isSupportedVideo(source) else {
            throw CocoaError(.fileReadUnsupportedScheme)
        }

        let id = UUID()
        let sourceExtension = source.pathExtension.lowercased()
        let converts = MediaConverter.needsConversion(sourceExtension)
        let ext = converts ? "mp4" : (sourceExtension.isEmpty ? "mp4" : sourceExtension)
        let fileName = "\(id.uuidString).\(ext)"
        let destination = videosDirectory.appendingPathComponent(fileName)

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        if converts {
            try MediaConverter.convert(source, to: destination)
        } else {
            try FileManager.default.copyItem(at: source, to: destination)
        }

        let metadata = videoMetadata(for: destination)
        let thumbName = "\(id.uuidString).jpg"
        let thumbURL = thumbsDirectory.appendingPathComponent(thumbName)
        let wroteThumb = writeThumbnail(from: destination, to: thumbURL)
        let loopMismatch = detectLoopMismatch(for: destination, duration: metadata.duration)

        return WallpaperItem(
            id: id,
            displayName: source.deletingPathExtension().lastPathComponent,
            fileName: fileName,
            thumbnailName: wroteThumb ? thumbName : nil,
            duration: metadata.duration,
            pixelWidth: metadata.width,
            pixelHeight: metadata.height,
            addedAt: Date(),
            loopMismatch: loopMismatch
        )
    }

    static func delete(_ item: WallpaperItem) {
        try? FileManager.default.removeItem(at: item.videoURL)
        if let thumbnailURL = item.thumbnailURL {
            try? FileManager.default.removeItem(at: thumbnailURL)
        }
    }

    private static func videoMetadata(for url: URL) -> (duration: TimeInterval?, width: Int?, height: Int?) {
        let asset = AVURLAsset(url: url)
        var duration: TimeInterval?
        var width: Int?
        var height: Int?
        let group = DispatchGroup()
        group.enter()
        Task {
            if let time = try? await asset.load(.duration) {
                let seconds = time.seconds
                if seconds.isFinite {
                    duration = seconds
                }
            }
            if let tracks = try? await asset.loadTracks(withMediaType: .video),
               let track = tracks.first,
               let naturalSize = try? await track.load(.naturalSize),
               let transform = try? await track.load(.preferredTransform) {
                let size = naturalSize.applying(transform)
                width = Int(abs(size.width.rounded()))
                height = Int(abs(size.height.rounded()))
            }
            group.leave()
        }
        _ = group.wait(timeout: .now() + 8)
        return (duration, width, height)
    }

    private static func writeThumbnail(from videoURL: URL, to destURL: URL) -> Bool {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 960, height: 540)
        generator.requestedTimeToleranceBefore = .positiveInfinity
        generator.requestedTimeToleranceAfter = .positiveInfinity
        do {
            let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
            let bitmap = NSBitmapImageRep(cgImage: cgImage)
            guard let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
                return false
            }
            try data.write(to: destURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    /// Compares the first and last frame so the UI can warn when a clip won't loop seamlessly.
    private static func detectLoopMismatch(for url: URL, duration: TimeInterval?) -> Bool? {
        guard let duration, duration > 1.2 else { return nil }

        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .positiveInfinity
        generator.requestedTimeToleranceAfter = .positiveInfinity
        let endTime = CMTime(seconds: max(0, duration - 0.15), preferredTimescale: 600)

        guard let startImage = try? generator.copyCGImage(at: .zero, actualTime: nil),
              let endImage = try? generator.copyCGImage(at: endTime, actualTime: nil)
        else {
            return nil
        }

        return frameDifference(startImage, endImage) > 0.12
    }

    private static func frameDifference(_ a: CGImage, _ b: CGImage) -> Double {
        let side = 12
        guard let pixelsA = averagedPixels(a, side: side), let pixelsB = averagedPixels(b, side: side) else {
            return 0
        }
        var total = 0.0
        for index in 0..<pixelsA.count {
            total += abs(Double(pixelsA[index]) - Double(pixelsB[index]))
        }
        return total / Double(pixelsA.count) / 255.0
    }

    private static func averagedPixels(_ image: CGImage, side: Int) -> [UInt8]? {
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        guard let context = CGContext(
            data: &pixels,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        return pixels
    }
}
