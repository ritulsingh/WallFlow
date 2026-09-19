import AppKit
import SwiftUI

struct HeroPlayerView: NSViewRepresentable {
    let url: URL
    let fill: Bool
    let isPlaying: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        context.coordinator.controller.attach(to: view)
        context.coordinator.apply(url: url, fill: fill, isPlaying: isPlaying)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.controller.layout()
        context.coordinator.apply(url: url, fill: fill, isPlaying: isPlaying)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.controller.teardown()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator {
        let controller = VideoLoopController()
        private var loadedURL: URL?

        func apply(url: URL, fill: Bool, isPlaying: Bool) {
            guard isPlaying else {
                controller.teardown()
                loadedURL = nil
                return
            }

            if loadedURL != url {
                controller.load(url: url, muted: true, fill: fill)
                loadedURL = url
            } else {
                controller.setFill(fill)
            }
            controller.play()
        }
    }
}
