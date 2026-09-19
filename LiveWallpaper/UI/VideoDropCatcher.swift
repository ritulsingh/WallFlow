import AppKit
import SwiftUI

/// Finder-reliable file drop target. SwiftUI `onDrop` often misses local video files.
struct VideoDropCatcher: NSViewRepresentable {
    @Binding var isTargeted: Bool
    var onDrop: (URL) -> Void

    func makeNSView(context: Context) -> VideoDropView {
        let view = VideoDropView()
        view.onTargetedChange = { isTargeted = $0 }
        view.onDropURL = onDrop
        return view
    }

    func updateNSView(_ nsView: VideoDropView, context: Context) {
        nsView.onTargetedChange = { isTargeted = $0 }
        nsView.onDropURL = onDrop
    }
}

final class VideoDropView: NSView {
    var onTargetedChange: ((Bool) -> Void)?
    var onDropURL: ((URL) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
        wantsLayer = true
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard firstSupportedVideo(from: sender) != nil else { return [] }
        onTargetedChange?(true)
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        firstSupportedVideo(from: sender) != nil ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onTargetedChange?(false)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        firstSupportedVideo(from: sender) != nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onTargetedChange?(false)
        guard let url = firstSupportedVideo(from: sender) else { return false }
        onDropURL?(url)
        return true
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        onTargetedChange?(false)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard super.hitTest(point) != nil else { return nil }
        if let event = NSApp.currentEvent {
            switch event.type {
            case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .scrollWheel:
                return nil
            default:
                break
            }
        }
        return self
    }

    private func firstSupportedVideo(from sender: NSDraggingInfo) -> URL? {
        let urls = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] ?? []
        return urls.first { WallpaperLibrary.isSupportedVideo($0) }
    }
}
