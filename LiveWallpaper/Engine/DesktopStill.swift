import AppKit
import AVFoundation

/// Mirrors the current clip's frame into the real macOS desktop picture so Mission Control,
/// Spaces, and the lock screen match the live wallpaper, and restores the user's original picture.
@MainActor
final class DesktopStill {
    static let shared = DesktopStill()

    private let originalsKey = "originalDesktopImagesV1"
    private var pending: Set<String> = []

    private init() {}

    private var stillsDirectory: URL {
        let url = WallpaperLibrary.rootDirectory.appendingPathComponent("Stills", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func sync() {
        let store = SettingsStore.shared
        for screen in NSScreen.screens {
            if store.setStaticDesktop, let item = store.wallpaperItem(for: screen.displayID) {
                apply(item, to: screen)
            } else {
                restoreOriginal(for: screen)
            }
        }
    }

    private func apply(_ item: WallpaperItem, to screen: NSScreen) {
        let size = screen.backingPixelSize
        let name = "\(item.id.uuidString)-\(Int(size.width))x\(Int(size.height)).jpg"
        let url = stillsDirectory.appendingPathComponent(name)

        if FileManager.default.fileExists(atPath: url.path) {
            rememberOriginal(for: screen)
            setImage(url, for: screen)
            return
        }

        guard pending.insert(name).inserted else { return }
        let videoURL = item.videoURL
        Task.detached(priority: .utility) {
            let wrote = await DesktopStill.writeStill(from: videoURL, to: url, maximumSize: size)
            await MainActor.run {
                DesktopStill.shared.pending.remove(name)
                if wrote {
                    DesktopStill.shared.sync()
                }
            }
        }
    }

    private func setImage(_ url: URL, for screen: NSScreen) {
        if NSWorkspace.shared.desktopImageURL(for: screen) == url { return }
        try? NSWorkspace.shared.setDesktopImageURL(
            url,
            for: screen,
            options: [
                .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
                .allowClipping: true
            ]
        )
    }

    private func rememberOriginal(for screen: NSScreen) {
        var originals = UserDefaults.standard.dictionary(forKey: originalsKey) as? [String: String] ?? [:]
        let key = String(screen.displayID)
        guard originals[key] == nil,
              let current = NSWorkspace.shared.desktopImageURL(for: screen),
              !current.path.hasPrefix(stillsDirectory.path)
        else {
            return
        }
        originals[key] = current.absoluteString
        UserDefaults.standard.set(originals, forKey: originalsKey)
    }

    private func restoreOriginal(for screen: NSScreen) {
        var originals = UserDefaults.standard.dictionary(forKey: originalsKey) as? [String: String] ?? [:]
        let key = String(screen.displayID)
        guard let stored = originals[key], let url = URL(string: stored) else { return }
        try? NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:])
        originals[key] = nil
        UserDefaults.standard.set(originals, forKey: originalsKey)
    }

    private nonisolated static func writeStill(from videoURL: URL, to destination: URL, maximumSize: CGSize) async -> Bool {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = maximumSize
        generator.requestedTimeToleranceBefore = .positiveInfinity
        generator.requestedTimeToleranceAfter = .positiveInfinity

        let duration = (try? await asset.load(.duration))?.seconds ?? 0
        let time = CMTime(seconds: duration.isFinite && duration > 2 ? 1 : 0, preferredTimescale: 600)

        do {
            let (image, _) = try await generator.image(at: time)
            let bitmap = NSBitmapImageRep(cgImage: image)
            guard let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.92]) else {
                return false
            }
            try data.write(to: destination, options: .atomic)
            return true
        } catch {
            return false
        }
    }
}
