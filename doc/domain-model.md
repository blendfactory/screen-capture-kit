# Domain Model: Screen Capture

This document defines the **aggregate root**, **entities**, and **value objects** for the Screen Capture bounded context. Value objects are implemented using **Dart extension types** (Dart 3+).

## Bounded context

**Screen Capture**: Content that can be captured (displays, windows, applications) and the results of capture (frames, images, audio). Boundaries: we do not model encoding, file formats, or external services; only capture targets and capture outputs.

---

## Aggregate: ShareableContent (aggregate root)

**Aggregate root**: `ShareableContent`

**Consistency boundary**: The aggregate is loaded in one shot from the native API (`SCShareableContent`). All references to displays, applications, and windows are contained within this root. No external entity holds a reference that must be kept consistent with ShareableContent; the root is the only entry point for reading content.

**Invariants**:

- `displays`, `applications`, and `windows` are non-null lists (may be empty).
- Each `Window` references an `RunningApplication` that is part of `applications`.
- No duplicate identities within each list (by `DisplayId`, `WindowId`, `ProcessId` as per entities below).

**Lifecycle**: Created when the application calls “get shareable content”. Immutable snapshot in Dart; native side may change after the snapshot.

```mermaid
flowchart TB
  subgraph Aggregate["Aggregate: ShareableContent"]
    AR["ShareableContent\n(aggregate root)"]
    AR --> E1["Display\n(entity)"]
    AR --> E2["Window\n(entity)"]
    AR --> E3["RunningApplication\n(entity)"]
  end
  E1 --> VO_D["DisplayId\n(value, extension type)"]
  E1 --> VO_S["FrameSize\n(value, extension type)"]
  E2 --> VO_W["WindowId\n(value, extension type)"]
  E2 --> VO_R["PixelRect\n(value, extension type)"]
  E3 --> VO_P["ProcessId\n(value, extension type)"]
```

---

## Entities (identity, part of aggregate)

Entities have **identity** (stable id over time). They are immutable snapshots in Dart.

| Entity | Identity | Description |
|--------|----------|-------------|
| **Display** | `DisplayId` | A display device. Contains `DisplayId`, `FrameSize` (width × height). |
| **Window** | `WindowId` | An on-screen window. Contains `WindowId`, `PixelRect` (frame), `RunningApplication` (owner), optional title. |
| **RunningApplication** | `ProcessId` (+ app name / bundle id for display) | A running app. Contains `ProcessId`, bundle identifier, application name. |

Entities reference **value objects** (IDs, rects, sizes) implemented as extension types. They do **not** hold raw `int`/`double` for ids and dimensions; they use the value object types.

---

## Value objects (IDs as extension types, others as immutable classes)

Value objects use **Dart extension types** for scalar identifiers, and **immutable classes** for multi-field structures (geometry, capture results).

### Identifier value objects (extension type on `int`)

| Value object | Representation | Purpose |
|--------------|----------------|---------|
| **DisplayId** | `int` | Display identifier (maps to native). |
| **WindowId** | `int` | Window identifier (maps to native). |
| **ProcessId** | `int` | Process identifier (maps to native). |
| **FilterId** | `int` | Opaque filter handle id (must be > 0). Used by `ContentFilterHandle`. |

Example:

```dart
extension type DisplayId(int value) {
  int get displayId => value;
}
extension type FilterId(int value) {
  int get filterId => value;
  /// Use at construction: FilterId(id) with id > 0.
}
```

`ContentFilterHandle` is the public API type for a filter; it can be an extension type on `FilterId` (or on `int`) and must enforce `value > 0` at construction.

### Geometric / size value objects (immutable classes)

| Value object | Representation | Purpose |
|--------------|----------------|---------|
| **FrameSize** | `(int width, int height)` | Width and height in pixels. |
| **PixelRect** | `(double x, double y, double width, double height)` | Rectangle in screen points (e.g. window frame, source rect). |

### Capture result value objects (immutable classes)

These represent a single frame, image, or audio buffer. They are **immutable** and defined by their data and metadata (no identity).

| Value object | Representation | Purpose |
|--------------|----------------|---------|
| **CapturedFrame** | Record `(Uint8List bgraData, int width, int height, int bytesPerRow)` | One video frame (BGRA pixels). |
| **CapturedImage** | Record `(Uint8List pngData, int width, int height)` | One screenshot (PNG bytes). |
| **CapturedAudio** | Record `(Uint8List pcmData, double sampleRate, int channelCount, String format)` | One audio buffer (PCM). |

These are modelled as immutable classes in the codebase; see the corresponding Dart files for concrete implementations.

---

## Domain model diagram (overview)

```mermaid
flowchart TB
  subgraph Aggregate["ShareableContent (aggregate root)"]
    SC["ShareableContent"]
    SC --> L1["List of Display"]
    SC --> L2["List of Window"]
    SC --> L3["List of RunningApplication"]
  end
  subgraph Entities["Entities"]
    D["Display\nDisplayId, FrameSize"]
    W["Window\nWindowId, PixelRect, RunningApplication"]
    RA["RunningApplication\nProcessId, bundleId, name"]
  end
  subgraph ValueObjects["Value objects (extension types)"]
    ID["DisplayId, WindowId, ProcessId, FilterId"]
    GEO["FrameSize, PixelRect"]
    CAP["CapturedFrame, CapturedImage, CapturedAudio"]
  end
  L1 --> D
  L2 --> W
  L3 --> RA
  D --> ID
  D --> GEO
  W --> ID
  W --> GEO
  RA --> ID
  CAP -.->|capture output| GEO
```

---

## Rules

1. **Value objects**: Implement scalar identifier value objects as **Dart extension types** (e.g. `DisplayId`, `WindowId`, `ProcessId`, `FilterId`), and model multi-field value objects (e.g. `FrameSize`, `PixelRect`, `CapturedFrame`, `CapturedImage`, `CapturedAudio`) as immutable classes.
2. **Entities**: Use value object types for ids and dimensions (e.g. `Display` has `DisplayId` and `FrameSize`, not raw `int`).
3. **Aggregate root**: Only `ShareableContent` is the aggregate root. All reads of “what can be captured” go through it. Do not add another root for the same consistency boundary.
4. **Capture results**: `CapturedFrame`, `CapturedImage`, and `CapturedAudio` are value objects (extension types); they are produced by the application/infrastructure layer and consumed by the caller; they do not belong to the ShareableContent aggregate.
5. **ContentFilterHandle**: Represents an opaque native filter. Model as a value object (extension type on `FilterId` or `int`) in the API layer; ensure `FilterId > 0` at construction and document that the handle must be released via the application service.

---

## File placement (domain layer)

- `domain/shareable_content.dart` — aggregate root.
- `domain/display.dart` — entity `Display` (uses `DisplayId`, `FrameSize`).
- `domain/window.dart` — entity `Window` (uses `WindowId`, `PixelRect`, references `RunningApplication`).
- `domain/running_application.dart` — entity `RunningApplication` (uses `ProcessId`).
- `domain/value_objects/` — value objects: `display_id.dart`, `window_id.dart`, `process_id.dart`, `filter_id.dart`, `frame_size.dart`, `pixel_rect.dart`, `captured_frame.dart`, `captured_image.dart`, `captured_audio.dart`.
- `domain/screen_capture_kit_exception.dart` — domain exception (no extension type).

Presentation/API may re-export `ContentFilterHandle` as an extension type on `FilterId` for the public API.
