import AppKit
import CoreGraphics

extension NSScreen {
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return deviceDescription[key] as? CGDirectDisplayID ?? 0
    }

    /// Screen frame in Quartz coordinates (origin at the top-left of the primary display).
    var quartzFrame: CGRect {
        let primary = NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.main
        let primaryHeight = primary?.frame.height ?? frame.height
        return CGRect(
            x: frame.origin.x,
            y: primaryHeight - frame.origin.y - frame.height,
            width: frame.width,
            height: frame.height
        )
    }

    var backingPixelSize: CGSize {
        CGSize(width: frame.width * backingScaleFactor, height: frame.height * backingScaleFactor)
    }
}
