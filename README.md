# WallFlow

A native macOS app that loops a short video as your desktop wallpaper — the Mac equivalent of the iPhone Lock Screen live wallpaper.

Apple’s desktop picture API only accepts still images. WallFlow places a click-through video window at the desktop layer, so Finder icons stay visible and clicks pass through to the desktop.

## Features

- Loop a local **MP4, MOV, or M4V** behind your icons
- **Multi-monitor** — one player per display
- **Mute** (on by default) and **scale to fill** or fit
- Play / pause from the main window or the menu bar
- Pause on **battery**, **Low Power Mode**, **fullscreen apps**, **lock**, and **display sleep**
- **Launch at login**
- Remembers the last clip across relaunch (security-scoped bookmark)

## Requirements

- macOS 14 or later
- Xcode 16 or later (to build)
- A short local video file

## Getting started

1. Open `LiveWallpaper.xcodeproj` in Xcode.
2. Select the **LiveWallpaper** scheme and run it on **My Mac**.
3. In the WallFlow controller, drop an MP4/MOV onto the preview, or click **Choose Video…**. The clip starts on your desktop right away.

The app stays running after you close the main window. Use the menu bar extra to play, pause, change the clip, open Settings, or quit.

```bash
xcodebuild -project LiveWallpaper.xcodeproj -scheme LiveWallpaper -configuration Debug -destination 'platform=macOS' build
```

## Recommended clips

Match Apple Lock Screen clips so the loop looks native and stays cheap on Apple Silicon:

- 5–15 seconds
- Muted H.264 or HEVC
- Resolution at least as large as your display
- First and last frames that match (seamless loop)

## Settings

| Option | Default | What it does |
| --- | --- | --- |
| Mute wallpaper | On | Silences the clip |
| Scale to fill | On | Crops to cover each display; off letterboxes |
| Pause on battery | On | Stops playback on battery power |
| Pause in Low Power Mode | On | Stops playback when Low Power Mode is on |
| Pause when an app is fullscreen | On | Pauses that display only |
| Launch at login | Off | Starts WallFlow with your Mac |

## How it works

```
Apps / Dock
Desktop icons
WallFlow video window   ← desktop window level, ignores mouse
macOS still wallpaper
```

Each display gets an `AVQueuePlayer` + `AVPlayerLooper` so short clips loop without a visible seek hitch.

## License

[MIT](LICENSE) © 2026 ritulsingh
