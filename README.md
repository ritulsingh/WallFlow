# WallFlow

<p align="center">
  <img src="LiveWallpaper/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="128" height="128" alt="WallFlow icon">
</p>

<p align="center">
  <strong>Live wallpaper for Mac.</strong><br>
  Loop a short video behind your desktop icons — the Mac equivalent of the iPhone Lock Screen.
</p>

macOS only accepts still images as the desktop picture. WallFlow places a click-through video window just under the icons, so Finder stays usable and the clip loops like a real wallpaper.

## Features

- Import local **MP4, MOV, or M4V** files into a library (copied into Application Support)
- **Set as Wallpaper** to play a clip on the desktop; browse other clips without starting them
- **Preview** a library clip in the app without running it in the background
- **Multi-monitor** — one player per display
- **Mute** (on by default) and **scale to fill** or fit
- Play / pause from the main window or the menu bar
- Pauses while you **work in another app**, browse a different clip, or an app goes **fullscreen**
- Also pauses on **Low Power Mode**, **lock**, and **display sleep**
- Optional pause on **battery**
- **Launch at login**
- Remembers your library and the current wallpaper across relaunch

## Requirements

- macOS 14 or later
- Xcode 16 or later (to build)
- A short local video file

## Install

1. Download **WallFlow-macOS.zip** from the [latest GitHub Release](https://github.com/ritulsingh/WallFlow/releases/latest).
2. Unzip it and drag **WallFlow** into **Applications**.
3. Open WallFlow.

Starting with the next release after Apple notarization credentials are added, Gatekeeper should accept the app without the right-click workaround. Current GitHub copies stay ad-hoc until those credentials exist.

Then drop a short MP4 or MOV onto the window, or click **Add Video**. Select a clip and choose **Set as Wallpaper**. Hide WallFlow or click the desktop to see it behind your icons.

The app stays running after you close the main window. Use the menu bar extra to play, pause, open WallFlow, or quit.

## Use

1. Import clips by drag-and-drop, **Add Video**, or **⌘O**.
2. Click a clip in the sidebar to inspect it. This does **not** start it as wallpaper.
3. Click **Set as Wallpaper** to play it on the desktop. Double-click a sidebar row to do the same.
4. **Preview** plays the selected clip in the app only. The desktop wallpaper stays paused.
5. While you work in another app, WallFlow pauses so the decoder is not running in the background. Click the desktop (or hide windows with **⌘H**) to resume.

## Build from source

1. Open `LiveWallpaper.xcodeproj` in Xcode.
2. Select the **LiveWallpaper** scheme and run it on **My Mac**.

```bash
# Debug
xcodebuild -project LiveWallpaper.xcodeproj -scheme LiveWallpaper -configuration Debug -destination 'platform=macOS' build

# Optimized zip in dist/WallFlow-macOS.zip
zsh scripts/package.sh
```

Pushing a `v*` tag publishes a GitHub Release from `scripts/package.sh`.

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
| Pause on battery | Off | Stops playback on battery power |
| Pause in Low Power Mode | On | Stops playback when Low Power Mode is on |
| Pause when an app is fullscreen | On | Pauses that display only |
| Pause while using other apps | On | Plays on the desktop; pauses while you work in another app |
| Launch at login | Off | Starts WallFlow with your Mac |

Playback also pauses when the Mac is locked, the displays sleep, or you browse another clip in the library.

## How it works

```
Apps / Dock
Desktop icons
WallFlow video window   ← just under icons, ignores mouse
macOS still wallpaper
```

Imported files live in `~/Library/Application Support/WallFlow/`. Each display gets an `AVQueuePlayer` + `AVPlayerLooper` so short clips loop without a visible seek hitch. Only one clip is decoded at a time.

## Project layout

```
LiveWallpaper/           # app sources (Xcode follows this folder)
  App/                   # @main, AppDelegate
  Engine/                # desktop windows, player, pause environment
  Store/                 # library + settings
  UI/                    # SwiftUI
  Assets.xcassets
scripts/package.sh       # Release zip (DerivedData stays in /tmp)
```

## Contributing

Bug reports, small fixes, and focused features are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, the project map, and pull-request expectations.

## License

[MIT](LICENSE) © 2026 ritulsingh
