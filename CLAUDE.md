# MojiSticker

macOS menubar sticker search app (Swift rewrite of weibo_emoji Python app).

## Tech Stack

- **Language**: Swift 5.9, macOS 14+ deployment target
- **UI**: SwiftUI + AppKit (NSPanel for floating search window)
- **Build**: XcodeGen (`project.yml`) generates `MojiSticker.xcodeproj`
- **Architecture**: MenuBarExtra (system tray only, LSUIElement=true)

## Commands

```bash
xcodegen generate                    # Regenerate .xcodeproj from project.yml
xcodebuild -scheme MojiSticker build # CLI build
```

## Directory Structure

```
MojiSticker/
├── App/        # MojiStickerApp entry point, AppDelegate with NSPanel
├── Models/     # Data models
├── Services/   # API, cache, clipboard services
├── Views/      # SwiftUI views
├── Utilities/  # Helpers
└── Resources/  # Info.plist, entitlements
```

## Key Conventions

- Single file max 300 lines; single function max 50 lines
- NSPanel for floating search window (not NSWindow)
- App runs as accessory (no Dock icon): `NSApp.setActivationPolicy(.accessory)`
- XcodeGen is the source of truth for project config, not .xcodeproj directly
