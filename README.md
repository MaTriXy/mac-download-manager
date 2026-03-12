# Mac Download Manager

A macOS download manager with cross-browser extension support. The Mac app uses aria2c for downloads and communicates with browser extensions via native messaging.

## Prerequisites

- macOS 14.0+
- Node.js 22+
- Xcode (Swift 6)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Project Structure

- `MacDownloadManager/` — macOS app (SwiftUI, GRDB, Sparkle)
- `NativeMessagingHelper/` — native messaging host for Chrome/Firefox/Edge
- `Extension/src/` — shared browser extension source
- `SafariExtension/` — Safari Web Extension (embedded in the Mac app)
- `scripts/build-extensions.js` — cross-browser build script
- `Tests/` — Swift unit tests + JS build tests

## Building Browser Extensions

```
npm install
npm run build
```

Outputs:
- `dist/chrome.zip`
- `dist/firefox.zip`
- `dist/edge.zip`

## Building the Mac App (includes Safari Extension)

```
xcodegen generate
xcodebuild -scheme MacDownloadManager -configuration Release build
```

The Safari Web Extension is embedded in the Mac app and built as part of the Xcode scheme.

## Native Messaging

The Mac app installs native messaging host manifests for Chrome, Firefox, and Edge. The `NativeMessagingHelper` binary is bundled inside the app.

## Testing

```
npm test                                     # 79 JS build tests
xcodebuild test -scheme MacDownloadManager   # 109 Swift tests
```

## CI/CD

GitHub Actions (`.github/workflows/build-extensions.yml`):
- **Push to `main`**: builds all four extensions, uploads as artifacts
- **Tag push (`v*`)**: builds all extensions and creates a GitHub Release with the zips
