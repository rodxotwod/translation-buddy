# Translator Buddy

Translator Buddy is a native macOS SwiftUI app for quick multi-language translation. It opens as a floating translator window, lets you type in any visible language panel, and keeps the other panels synced.

## Download And Install

The latest packaged app is committed in a GitHub-friendly download folder:

```text
github-download/TranslatorBuddy/Translator Buddy.zip
```

The build script also writes the same archive to:

```text
dist/Translator Buddy.zip
```

To use it on another Mac:

1. Download `github-download/TranslatorBuddy/Translator Buddy.zip` from this repository.
2. Unzip it.
3. Move `Translator Buddy.app` to your `Applications` folder if you want it installed like a normal Mac app.
4. Open `Translator Buddy.app`.

Because this app is currently ad-hoc signed and not notarized by Apple, macOS Gatekeeper may block the first launch. If that happens, right-click the app and choose **Open**.

If macOS still blocks it, remove the quarantine flag after unzipping:

```bash
xattr -dr com.apple.quarantine "/path/to/Translator Buddy.app"
```

For a frictionless double-click install on other Macs, the app needs Developer ID signing and Apple notarization.

## Build A Fresh Package

From the project root:

```bash
./scripts/package_app.sh
```

This creates:

```text
dist/Translator Buddy.app
dist/Translator Buddy.zip
```

To update the committed GitHub download artifact after packaging:

```bash
mkdir -p "github-download/TranslatorBuddy"
cp "dist/Translator Buddy.zip" "github-download/TranslatorBuddy/Translator Buddy.zip"
```

## Development

Run tests:

```bash
swift test
```

Run from source:

```bash
swift run TranslatorBuddy
```
