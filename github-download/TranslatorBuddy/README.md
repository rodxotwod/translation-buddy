# Translator Buddy Download

This folder contains a ready-to-install build of Translator Buddy:

```text
Translator Buddy.zip
```

## Install On Another Mac

1. Download `Translator Buddy.zip`.
2. Unzip it.
3. Move `Translator Buddy.app` to your `Applications` folder if you want it installed like a normal Mac app.
4. Open `Translator Buddy.app`.

## If macOS Blocks The App

This build is currently ad-hoc signed and not notarized by Apple. On first launch, macOS may block it.

Try right-clicking `Translator Buddy.app` and choosing **Open**.

If it is still blocked, remove the quarantine flag:

```bash
xattr -dr com.apple.quarantine "/path/to/Translator Buddy.app"
```

Then open the app again.

## Notes

- The app uses macOS local Translation capabilities.
- The global shortcut opens the app and focuses the main translation panel so you can start typing immediately.
- For smooth public distribution without Gatekeeper warnings, the app should be signed with a Developer ID certificate and notarized by Apple.
