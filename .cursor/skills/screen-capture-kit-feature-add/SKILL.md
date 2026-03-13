---
name: screen-capture-kit-feature-add
description: >-
  Workflow for adding a new ScreenCaptureKit feature to the package. Use when
  implementing display capture, window capture, audio, or other features from
  the roadmap.
---

# ScreenCaptureKit Feature Add Workflow

Step-by-step workflow for adding a new ScreenCaptureKit feature to the screen-capture-kit Dart package.

## When to use

- Implementing a new feature (e.g. window capture, audio capture)
- Adding a new ScreenCaptureKit API to the Dart surface
- Following the roadmap items

## Workflow

### 1. Verify spec and coverage

- Use `screen-capture-kit-spec` to confirm the exact Swift APIs involved
- Use `screen-capture-kit-api-coverage` to see current status and update checklist

### 2. Design Dart API

- **Naming:** Match Dart conventions (camelCase, clear names)
- **Types:** Map Swift types to Dart (see `screen-capture-kit-native-bridge`)
- **Async:** Use `Future` for one-shot, `Stream` for continuous output
- **Errors:** Define clear exceptions; map `SCStreamError` codes

### 3. Implement Swift bridge

- Add native Swift code in the package's native asset directory
- Follow patterns from `screen-capture-kit-native-bridge`:
  - Completion handlers → async bridge
  - Callbacks → StreamController
  - CMSampleBuffer → frame/audio bytes
- Ensure permission checks (Screen Recording) where needed

### 4. Expose Dart API

- Add public API in `lib/screen_capture_kit.dart` (or sublibrary)
- Document with `///` per `dart-standards.mdc`
- Keep API minimal; avoid unnecessary dependencies

### 5. Update example

- Add or update example in `example/` to demonstrate the feature
- Ensure it runs on macOS 12.3+

### 6. Add tests

- Unit tests for Dart logic (use `mocktail` per `dart-standards.mdc`)
- Integration tests if feasible (e.g. with permission granted)

### 7. Update docs and coverage

- Update README if the feature is user-facing
- Update `screen-capture-kit-api-coverage` checklist
- Update README Roadmap if the item is complete

### 8. Commit

- Follow `commit-message-standards.mdc`
- Use scope `feat(native)` or `feat(dart)` as appropriate
- Include reference link in body (e.g. Apple docs)

## Example: Adding window capture

1. **Spec:** `SCContentFilter(desktopIndependentWindow:)`, `SCWindow`, `SCShareableContent.windows`
2. **Dart API:** `Future<List<Window>> getWindows()`, `Stream<Frame> startWindowCapture(Window window)`
3. **Swift:** Implement filter creation, stream setup, output handling
4. **Docs:** Add `///` to new public members
5. **Example:** Add window selection + capture to example app
6. **Tests:** Add tests for window list, capture start/stop
7. **Coverage:** Mark SCContentFilter(desktopIndependentWindow), SCWindow as ✅
8. **Commit:** `feat(native): add window capture API`

## Reference

- `screen-capture-kit-spec` — API details
- `screen-capture-kit-native-bridge` — Bridging patterns
- `screen-capture-kit-api-coverage` — Coverage checklist
- `dart-standards.mdc` — Dart conventions
