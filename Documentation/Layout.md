# ImageCompare — Layout

```
ImageCompare.xcodeproj         Xcode project (file-system synchronized groups: new files are picked up automatically)
ImageCompare/                  App target
  ImageCompareApp.swift        @main, window scene, menu commands
  ComparisonCommands.swift     FocusedValues keys + File/Compare menu items and shortcuts
  ContentView.swift            Per-window state, toolbar, file import, drop handling, diff task
  Model/                       Value types with no UI: ComparisonImage (loading), ImagePair, ComparisonMode, Viewport, SwipeDivider, DiffResult
  Diff/                        Core Image code: ImageDiffer (pipeline) and CIImage/CIContext helpers
  Views/                       SwiftUI views: one per mode, ZoomableCanvas (shared zoom/pan), PixelImage, InfoBar, ImageDropSlot
ImageCompareTests/             Swift Testing unit tests (ImageDiffer, Viewport, SwipeDivider); images are generated in code
ImageCompareUITests/           Xcode template UI tests (launch only)
Documentation/                 This documentation
scripts/build-dmg.sh           Release build + DMG packaging (see below)
dist/                          DMG output (git-ignored)
build/                         Script's DerivedData and DMG staging (git-ignored)
```

New comparison modes go in `Views/` plus a case in `Model/ComparisonMode.swift`; `ContentView.modeView` switches on the mode. Diffing logic stays in `Diff/` and should be covered by `ImageCompareTests`.

## Building a DMG

`./scripts/build-dmg.sh` builds the Release app with `xcodebuild` and writes `dist/ImageCompare-<version>.dmg`, which contains the app and an Applications shortcut. It ad-hoc signs by default, so the app runs on this Mac but Gatekeeper will block it on others. To distribute it, set `SIGN_IDENTITY` (a Developer ID Application identity) and `DEVELOPMENT_TEAM`. The script doesn't notarize.
