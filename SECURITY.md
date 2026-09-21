# Security Policy

Thanks for helping keep WallFlow and its users safe.

## Supported versions

Security fixes are released for the **latest version** only. Please update before reporting, and check that the issue still happens.

| Version | Supported |
| --- | --- |
| Latest release ([see Releases](https://github.com/ritulsingh/WallFlow/releases/latest)) | Yes |
| Older releases | No |

## Reporting a vulnerability

**Please do not open a public issue for security problems.**

Report it privately through GitHub:

1. Go to the [Security tab](https://github.com/ritulsingh/WallFlow/security) of this repository.
2. Choose **Report a vulnerability**.
3. Describe the problem and how to reproduce it.

Helpful details to include:

- WallFlow version and macOS version
- Steps to reproduce, or a proof of concept
- What an attacker could do with it
- Any suggested fix

## What to expect

- **Acknowledgement** within 7 days.
- **An assessment** and a plan within 14 days.
- **A fix** for confirmed issues as soon as practical, typically within 90 days, released as a new version through GitHub Releases and Sparkle.
- **Credit** in the release notes if you would like it.

Please give me reasonable time to fix the issue before sharing it publicly (coordinated disclosure).

## Scope

In scope:

- The WallFlow app and its source code in this repository
- The update mechanism (Sparkle feed, `appcast.xml`, and update signing)
- The release pipeline (GitHub Actions workflows and packaging scripts)
- Handling of imported or downloaded files, including GIF, WebM, MKV, and AVI conversion
- Sandbox and entitlement issues

Out of scope:

- Vulnerabilities in third-party software, such as Sparkle, ffmpeg, or macOS itself (please report those upstream)
- Content of videos you choose to import
- Attacks that need physical access to an unlocked Mac
- Social engineering, spam, or denial of service against GitHub
- Missing notarization. Current releases are signed ad-hoc and are not notarized yet, which is a known limitation and not a vulnerability

## How WallFlow is designed for safety

- **App Sandbox:** WallFlow runs sandboxed and can only read files you pick, drop, or download.
- **No sensitive permissions:** it does not need Screen Recording, Accessibility, Camera, Microphone, or Full Disk Access.
- **Network use is limited** to checking for updates on GitHub and downloading a link you paste into **Import from URL**. No analytics or telemetry.
- **Signed updates:** Sparkle only installs updates signed with WallFlow's EdDSA key. The private key is stored as a GitHub Actions secret and is never committed.
- **Local conversion:** WebM, MKV, and AVI files are converted by a locally installed `ffmpeg`. WallFlow copies the file to a temporary folder first and only runs `ffmpeg` from `/opt/homebrew/bin` or `/usr/local/bin`.

### Known trade-offs

These entitlements are in `LiveWallpaper/WallFlow.entitlements`, and I want to be open about why they exist:

- `com.apple.security.cs.disable-library-validation` lets the ad-hoc signed app load the embedded Sparkle framework. It can be removed once releases are signed with a Developer ID certificate.
- `com.apple.security.temporary-exception.files.absolute-path.read-only` for `/opt/homebrew/` and `/usr/local/` lets WallFlow run a Homebrew-installed `ffmpeg`.

## Staying safe as a user

- Only download WallFlow from the [official GitHub Releases page](https://github.com/ritulsingh/WallFlow/releases).
- Keep WallFlow updated. It checks for updates once a day.
- Only import videos and links from sources you trust.
