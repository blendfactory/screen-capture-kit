# Intended Use Cases

This document describes the use cases this package is designed to support. The package focuses on **capture** only; downstream processing (summarization, translation, etc.) is done by other tools in combination.

## Primary use cases

1. **Multiple screen captures**  
   Capture several displays, windows, or regions (screenshots or streams). Use `getShareableContent` → `createDisplayFilter` / `createWindowFilter` / `presentContentSharingPicker` → `captureScreenshot` or `startCaptureStream`.

2. **Recording video and audio**  
   Record video calls, meetings, or screen+system audio. Use capture streams (`startCaptureStream` / `startCaptureStreamWithUpdater`) with `capturesAudio: true` and optionally `captureMicrophone: true`. Consumers pipe `Stream<CapturedFrame>` and `Stream<CapturedAudio>` into their own encoding/recording pipeline.

3. **Real-time or post-hoc summarization and NextAction**  
   Feed captured content (frames and/or audio) into other tools for:
   - Real-time or post-meeting **summarization**
   - **NextAction** extraction and organization  
   This package only provides the capture streams; summarization and action extraction are out of scope and implemented elsewhere.

4. **Meeting (MTG) translation and voice handling**  
   - **Incoming**: Capture the other party’s audio (e.g. system audio or microphone), run it through external translation/TTS (e.g. English → Japanese), and play the translated audio.
   - **Outgoing**: Capture this side’s voice (microphone), translate (e.g. Japanese → English), and send the result to the call via another tool.  
   This package provides the **audio capture** (`CaptureStream.audioStream`, `CaptureStream.microphoneStream`); translation and injection into the call are handled by other tools.

## Role of this package

- **In scope**: High-quality, low-latency capture of screen(s), window(s), system audio, and microphone on macOS. Public API is stream- and future-based so that consumers can plug into their own pipelines.
- **Out of scope**: Summarization, translation, TTS, recording file format, video encoding, and sending audio/video into a call. Those are implemented by combining this package with other tools (e.g. transcription APIs, translation services, recording/streaming pipelines).

## Design implications

- Keep **streams** first-class (`Stream<CapturedFrame>`, `Stream<CapturedAudio>`) for real-time pipelines.
- Keep **single-shot** capture (`captureScreenshot`) for simple snapshot use cases.
- Support **system audio and microphone** capture so MTG and recording use cases can consume raw audio and pass it to external tools.
- Avoid adding summarization, translation, or encoding inside this package; stay a **capture-only** building block.
