# ImageCompare — Overview

A native macOS app for comparing two images, modeled on Kaleidoscope's image mode.

## Features
- Drop two image files onto the Dock icon (or use Finder’s Open With) to open them together in a new comparison. One file opens on the left; additional files beyond the first two are ignored.
- Load a left and right image by dropping files (two at once fills both sides) or with ⌘O / ⌘⇧O.
- Four comparison modes (toolbar or ⌥1–⌥4):
  - **Swipe** (default): one view split by a divider. Like Kaleidoscope, each of its two handles can be dragged anywhere along the frame, though never onto the same edge as the other handle. That includes the corner shared with the other handle's edge, which would collapse the line onto the frame. The right image fills the region clockwise from the first handle to the second, so by default (top to bottom) it's on the right. Drag the line to slide it at a fixed angle, with ends moving around corners as needed. Double-click a handle to straighten the divider back to vertical. The geometry lives in `Model/SwipeDivider.swift`.
  - **Side by Side**: two panes, zoom/pan synced.
  - **Onion Skin**: the right image over the left at adjustable opacity.
  - **Difference**: the right image desaturated and dimmed, with pixels above a ΔE threshold painted red. Shows % of pixels that differ and max ΔE.
- Zoom: pinch, drag to pan, ⌘= / ⌘- / ⌘0 (fit) / ⌘1 (actual size). "Fit" stays fitted as the window resizes.
- Swap left/right: ⌃⌘S.
- Images of different sizes are anchored top-left on a shared canvas; area covered by only one image counts as different.

## Technology
- SwiftUI, macOS 26+, Swift 6 with MainActor default isolation and approachable concurrency.
- Core Image for all diffing, on the GPU. No third-party dependencies.
- Swift Testing for unit tests.

## Architecture
- No ViewModels. `ContentView` owns each window's state as `@State` value types (`ImagePair`, `Viewport`, `ComparisonMode`, ...); mode views only render it.
- Menu commands reach the frontmost window through `FocusedValues` bindings (`ComparisonCommands.swift`).
- `ImageDiffer` is a `Sendable` struct whose `diff` is `@concurrent`, so it runs off the main actor. ContentView re-runs it with `.task(id:)` when the images or threshold change, with a 120 ms debounce.

## Diff pipeline (`ImageDiffer`)
1. Pad both images to the union canvas, anchored top-left.
2. `CILabDeltaE` gives per-pixel CIE ΔE 1994 (0–100; ~2 is just noticeable).
3. Threshold into a 0/1 mask, OR'd with the "covered by only one image" area.
4. `CIAreaAverage` of the mask gives the differing fraction. `CIAreaMaximum` of ΔE over the overlap gives max ΔE. Both are 1-pixel GPU reductions.
5. `CIBlendWithMask` paints red over a desaturated, 35%-opacity copy of the right image.

**Gotcha:** `CILabDeltaE` writes ΔE into *all four channels, alpha included*. Core Image un-premultiplies before color filters, so `CIColorThreshold` only ever sees RGB = 1 and is useless here. The mask is built with a `CIColorMatrix` that reads ΔE from alpha, followed by `CIColorClamp`. See `ImageDiffer.thresholdMask`.

## Known limitations / possible next steps
- 100% zoom is one image pixel per *point* (two physical pixels on Retina).
- No scroll-wheel/two-finger panning yet (needs an NSView bridge); drag to pan.
- No alignment of shifted or scaled images, no folder comparison.
- Images are decoded to 8-bit sRGB `CGImage`s, so wide-gamut/HDR differences are reduced to sRGB.
