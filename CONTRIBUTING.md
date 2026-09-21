# Contributing to WallFlow

Thanks for helping. WallFlow is a native **macOS 14+** SwiftUI + AppKit app. There is no iOS target and no public video-wallpaper API — the engine places a click-through player just under desktop icons.

## Before you start

1. Use **macOS 14** or later and **Xcode 16** or later.
2. Search [existing issues](https://github.com/ritulsingh/WallFlow/issues) before opening a new one.
3. For a non-trivial change, open an issue first so we can agree on the approach.

## Development setup

```bash
git clone https://github.com/ritulsingh/WallFlow.git
cd WallFlow
open WallFlow.xcodeproj
```

Select the **WallFlow** scheme and run it on **My Mac** (⌘R).

```bash
# Debug build
xcodebuild -project WallFlow.xcodeproj -scheme WallFlow \
  -configuration Debug -destination 'platform=macOS' build

# Release zip in dist/WallFlow-macOS.zip
zsh scripts/package.sh
```

Xcode follows the `LiveWallpaper/` folder. Add new Swift files there — you do not need to edit `project.pbxproj` by hand.

## Project map

| Path | What lives there |
| --- | --- |
| `LiveWallpaper/App/` | `@main`, AppDelegate, Sparkle updater |
| `LiveWallpaper/Engine/` | Desktop windows, video loop, pause environment |
| `LiveWallpaper/Store/` | Library import and per-display settings |
| `LiveWallpaper/UI/` | SwiftUI |
| `scripts/` | Package / signing helpers |
| `.github/workflows/` | PR CI + tag `v*` GitHub Release |

Imported clips are copied into `~/Library/Application Support/WallFlow/`. Do not check videos, thumbnails, or `dist/` into git.

## How to contribute

### Bugs

Open an issue with:

- macOS version and Mac model (Intel / Apple Silicon)
- WallFlow version (or commit)
- What you expected vs what happened
- Whether the clip plays in the hero, on the desktop, or neither

### Features

Keep the product a **local live wallpaper** for Mac:

- Short local **MP4 / MOV / M4V** files
- One decoder per display (clips can differ across monitors)
- Pause when another app is in front, on Low Power Mode, fullscreen, lock, or display sleep
- Click-through desktop window under icons

Online catalogs, iOS ports, and unsigned malware-style injectors are out of scope.

### Pull requests

1. Fork and create a branch from `main` (`fix/…` or `feat/…`).
2. Keep the change focused. Do not mix formatting-only diffs with behavior.
3. Build with the Debug command above.
4. Exercise the path you touched: import, **Set as Wallpaper**, Preview, pause in another app, multi-display if you have one.
5. Open a PR against `main`. Describe **why**, not only what.

## Code style

- Swift 5, `@MainActor` for UI and playback.
- Prefer small types in the existing folders over new layers.
- Do not start a second `AVPlayer` on the same display.
- Do not call `play()` until the item is ready; use the existing loop controller.
- Persist settings off the view-update path (`Task { @MainActor in … }`), not inside a `didSet` that SwiftUI is rendering.
- Leave `CODE_SIGN_IDENTITY = "-"` in the project for local Debug. Signing and notarization belong in `scripts/` and CI secrets, not in source.

## What not to commit

- Certificates (`.p12`), API keys (`.p8`), provisioning profiles
- `dist/`, DerivedData, `.DS_Store`
- Large sample videos

## Releases

Maintainers cut releases by bumping `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` and pushing a `v*` tag. GitHub Actions runs `scripts/package.sh`. Do not push tags from a feature PR.

## License

By contributing, you agree that your work is licensed under the [MIT License](LICENSE), the same as WallFlow.
