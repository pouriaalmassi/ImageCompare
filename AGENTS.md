# ImageCompare project guidance

## Project context

- Native macOS image comparison app using Swift 6, SwiftUI, AppKit where needed, and Core Image. The current deployment target is macOS 26.
- Read `Documentation/Overview.md` and `Documentation/Layout.md` before changing comparison behavior or interaction design.
- Preserve the existing architecture: `ContentView` owns per-window state as `@State` value types; mode views render it. Avoid introducing view models, shared singletons, or third-party dependencies without a clear requirement.
- Keep models and geometry in `ImageCompare/Model`, image processing in `ImageCompare/Diff`, and rendering components in `ImageCompare/Views`.

## Swift and concurrency

- Match the surrounding tab indentation, naming, access control, and declaration ordering. Prefer small value types, explicit dependencies, and focused functions.
- Handle recoverable failures with typed errors and useful UI feedback. Avoid force unwraps and `try!` in production paths.
- Respect the project's MainActor default isolation and existing explicit `nonisolated` declarations. Keep UI state on the main actor and expensive decoding/rendering away from it.
- Prefer structured concurrency and cancellation-aware tasks. Preserve the existing `@concurrent` image-diff work, `.task(id:)` lifecycle, debounce, and cancellation checks; prevent stale results from replacing newer input.
- Resolve isolation and Sendable warnings at their source. Do not suppress them with `@unchecked Sendable`, unsafe isolation, or detached tasks merely to satisfy the compiler.

## SwiftUI and macOS

- Keep view bodies inexpensive and free of side effects. Extract views around meaningful responsibilities, and use bindings for state owned by a parent.
- Use native macOS controls, menus, keyboard shortcuts, focus, and window behavior. Preserve `FocusedValues` routing to the frontmost comparison window.
- Support keyboard navigation, VoiceOver labels for custom controls, light/dark appearance, and usable resizing. Give custom drag handles usable hit targets without changing image geometry.
- Use AppKit bridges only when needed for desktop behavior SwiftUI cannot express cleanly. Check API availability against the deployment target.
- Preserve drag-and-drop, Finder Open With/Dock opening, and multi-window behavior. Keep file-access permissions scoped to the required operation.

## Image correctness and performance

- Preserve top-left alignment on the union canvas; pixels covered by only one image count as differences. Keep zoom/pan consistent across comparison modes.
- Distinguish image pixels, view points, and Retina backing pixels. Do not silently change the current actual-size zoom semantics.
- Preserve the Core Image/GPU pipeline and shared rendering context. Avoid full-resolution CPU pixel loops, repeated decoding, or image rendering inside view bodies.
- Preserve color-space, orientation, alpha, and threshold semantics. Read the documented CILabDeltaE alpha-channel caveat before changing the difference mask.

## Verification

- Use Swift Testing for model, geometry, and diff regression tests in `ImageCompareTests`; follow existing XCTest UI tests in `ImageCompareUITests` for user workflows.
- From the repository root, build and run the relevant tests using the existing Xcode scheme:

  ```sh
  xcodebuild -project ImageCompare.xcodeproj -scheme ImageCompare -destination 'platform=macOS' build
  xcodebuild -project ImageCompare.xcodeproj -scheme ImageCompare -destination 'platform=macOS' test
  ```

- For interaction changes, also check the affected comparison modes, differently sized images, zoom/pan, resizing, and keyboard access. Report any verification you could not perform.
- Do not change signing identities, bundle identifiers, deployment targets, or release packaging as a side effect. Run `scripts/build-dmg.sh` only when packaging is part of the task.
- Keep generated `build/` and `dist/` artifacts out of commits, and preserve unrelated working-tree changes.
