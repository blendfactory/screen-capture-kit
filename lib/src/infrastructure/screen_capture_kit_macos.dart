import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:screen_capture_kit/src/domain/entities/display.dart';
import 'package:screen_capture_kit/src/domain/entities/running_application.dart';
import 'package:screen_capture_kit/src/domain/entities/shareable_content.dart';
import 'package:screen_capture_kit/src/domain/entities/window.dart';
import 'package:screen_capture_kit/src/domain/errors/screen_capture_kit_exception.dart';
import 'package:screen_capture_kit/src/domain/value_objects/capture/captured_audio.dart';
import 'package:screen_capture_kit/src/domain/value_objects/capture/captured_frame.dart';
import 'package:screen_capture_kit/src/domain/value_objects/capture/captured_image.dart';
import 'package:screen_capture_kit/src/domain/value_objects/capture/content_sharing_picker_configuration.dart';
import 'package:screen_capture_kit/src/domain/value_objects/capture/content_sharing_picker_mode.dart';
import 'package:screen_capture_kit/src/domain/value_objects/capture/display_refresh_rate.dart';
import 'package:screen_capture_kit/src/domain/value_objects/capture/frame_rate.dart';
import 'package:screen_capture_kit/src/domain/value_objects/capture/queue_depth.dart';
import 'package:screen_capture_kit/src/domain/value_objects/capture/stream_configuration.dart';
import 'package:screen_capture_kit/src/domain/value_objects/geometry/frame_size.dart';
import 'package:screen_capture_kit/src/domain/value_objects/geometry/pixel_rect.dart';
import 'package:screen_capture_kit/src/domain/value_objects/identifiers/bundle_id.dart';
import 'package:screen_capture_kit/src/domain/value_objects/identifiers/display_id.dart';
import 'package:screen_capture_kit/src/domain/value_objects/identifiers/filter_id.dart';
import 'package:screen_capture_kit/src/domain/value_objects/identifiers/process_id.dart';
import 'package:screen_capture_kit/src/domain/value_objects/identifiers/window_id.dart';
import 'package:screen_capture_kit/src/presentation/capture_stream.dart';

/// C function returning malloc'd JSON string. Caller must free.
@Native<Pointer<Utf8> Function(Int32, Int32)>(
  symbol: 'get_shareable_content_json',
  assetId: 'package:screen_capture_kit/screen_capture_kit.dart',
)
external Pointer<Utf8> _getShareableContentJson(
  int excludeDesktopWindows,
  int onScreenWindowsOnly,
);

/// Creates native SCContentFilter for a window. Returns filter id; 0 on error.
@Native<Int64 Function(Int64)>(
  symbol: 'create_content_filter_for_window',
  assetId: 'package:screen_capture_kit/screen_capture_kit.dart',
)
external int _createContentFilterForWindow(int windowId);

/// Creates native SCContentFilter for a display. Returns filter id; 0 on error.
@Native<Int64 Function(Int64)>(
  symbol: 'create_content_filter_for_display',
  assetId: 'package:screen_capture_kit/screen_capture_kit.dart',
)
external int _createContentFilterForDisplay(int displayId);

/// Creates native SCContentFilter for display excluding given windows.
/// windowIdsJson: JSON array of window IDs; caller frees ptr.
@Native<Int64 Function(Int64, Pointer<Utf8>)>(
  symbol: 'create_content_filter_for_display_excluding_windows',
  assetId: 'package:screen_capture_kit/screen_capture_kit.dart',
)
external int _createContentFilterForDisplayExcludingWindows(
  int displayId,
  Pointer<Utf8> windowIdsJson,
);

@Native<Void Function(Int64)>(
  symbol: 'release_content_filter',
  assetId: 'package:screen_capture_kit/screen_capture_kit.dart',
)
external void _releaseContentFilter(int filterId);

/// Captures a screenshot. Returns malloc'd JSON. Caller must free.
@Native<Pointer<Utf8> Function(Int64, Int32, Int32)>(
  symbol: 'capture_screenshot',
  assetId: 'package:screen_capture_kit/screen_capture_kit.dart',
)
external Pointer<Utf8> _captureScreenshot(int filterId, int width, int height);

@Native<
  Int64 Function(
    Int64,
    Int32,
    Int32,
    Int32,
    Float,
    Float,
    Float,
    Float,
    Int32,
    Int32,
    Int32,
    Int32,
    Int32,
    Uint32,
    Pointer<Utf8>,
  )
>(
  symbol: 'stream_create_and_start',
  assetId: 'package:screen_capture_kit/screen_capture_kit.dart',
)
external int _streamCreateAndStart(
  int filterId,
  int width,
  int height,
  int frameRate,
  double srcX,
  double srcY,
  double srcWidth,
  double srcHeight,
  int showsCursor,
  int queueDepth,
  int capturesAudio,
  int excludesCurrentProcessAudio,
  int captureMicrophone,
  int pixelFormat,
  Pointer<Utf8> colorSpaceName,
);

@Native<Pointer<Void> Function(Int64, Int64)>(
  symbol: 'stream_get_next_frame',
  assetId: 'package:screen_capture_kit/screen_capture_kit.dart',
)
external Pointer<Void> _streamGetNextFrame(int streamId, int timeoutMs);

@Native<Pointer<Utf8> Function(Int64, Int64)>(
  symbol: 'stream_get_next_audio',
  assetId: 'package:screen_capture_kit/screen_capture_kit.dart',
)
external Pointer<Utf8> _streamGetNextAudio(int streamId, int timeoutMs);

@Native<Pointer<Utf8> Function(Int64, Int64)>(
  symbol: 'stream_get_next_microphone',
  assetId: 'package:screen_capture_kit/screen_capture_kit.dart',
)
external Pointer<Utf8> _streamGetNextMicrophone(int streamId, int timeoutMs);

@Native<Void Function(Int64)>(
  symbol: 'stream_stop_and_release',
  assetId: 'package:screen_capture_kit/screen_capture_kit.dart',
)
external void _streamStopAndRelease(int streamId);

/// Returns malloc'd JSON for last stream error, or null. Caller must free.
@Native<Pointer<Utf8> Function()>(
  symbol: 'stream_get_last_error',
  assetId: 'package:screen_capture_kit/screen_capture_kit.dart',
)
external Pointer<Utf8> _streamGetLastError();

/// Updates running stream config. Returns 0 on success, -1 on error.
@Native<
  Int32 Function(
    Int64,
    Int32,
    Int32,
    Int32,
    Float,
    Float,
    Float,
    Float,
    Int32,
    Int32,
    Int32,
    Int32,
    Int32,
    Uint32,
    Pointer<Utf8>,
  )
>(
  symbol: 'stream_update_configuration',
  assetId: 'package:screen_capture_kit/screen_capture_kit.dart',
)
external int _streamUpdateConfiguration(
  int streamId,
  int width,
  int height,
  int frameRate,
  double srcX,
  double srcY,
  double srcWidth,
  double srcHeight,
  int showsCursor,
  int queueDepth,
  int capturesAudio,
  int excludesCurrentProcessAudio,
  int captureMicrophone,
  int pixelFormat,
  Pointer<Utf8> colorSpaceName,
);

@Native<Int32 Function(Int64, Int64)>(
  symbol: 'stream_update_content_filter',
  assetId: 'package:screen_capture_kit/screen_capture_kit.dart',
)
external int _streamUpdateContentFilter(int streamId, int filterId);

/// Presents the system content-sharing picker.
/// Returns malloc'd JSON. Caller must free.
@Native<Pointer<Utf8> Function(Pointer<Utf8>)>(
  symbol: 'picker_present',
  assetId: 'package:screen_capture_kit/screen_capture_kit.dart',
)
external Pointer<Utf8> _pickerPresent(Pointer<Utf8> allowedModesJson);

@Native<Int32 Function()>(
  symbol: 'picker_is_active',
  assetId: 'package:screen_capture_kit/screen_capture_kit.dart',
)
external int _pickerIsActive();

@Native<Int32 Function()>(
  symbol: 'picker_maximum_stream_count',
  assetId: 'package:screen_capture_kit/screen_capture_kit.dart',
)
external int _pickerMaximumStreamCount();

@Native<Int32 Function(Int64, Pointer<Utf8>)>(
  symbol: 'stream_set_picker_configuration',
  assetId: 'package:screen_capture_kit/screen_capture_kit.dart',
)
external int _streamSetPickerConfiguration(
  int streamId,
  Pointer<Utf8> configJson,
);

ShareableContent getShareableContentImpl({
  bool excludeDesktopWindows = false,
  bool onScreenWindowsOnly = true,
}) {
  if (!Platform.isMacOS) {
    throw UnsupportedError(
      'screen_capture_kit only supports macOS. '
      'Current platform: ${Platform.operatingSystem}',
    );
  }

  final ptr = _getShareableContentJson(
    excludeDesktopWindows ? 1 : 0,
    onScreenWindowsOnly ? 1 : 0,
  );
  if (ptr == nullptr) {
    throw const ScreenCaptureKitException(
      'Failed to retrieve shareable content from native bridge.',
    );
  }

  String jsonStr;
  try {
    jsonStr = ptr.toDartString();
  } finally {
    malloc.free(ptr);
  }

  final json = jsonDecode(jsonStr) as Map<String, dynamic>;

  if (json['error'] == true) {
    final domain = json['domain'] as String? ?? '';
    final code = json['code'] as int? ?? 0;
    final desc = json['localizedDescription'] as String? ?? '';
    final message = _buildNativeErrorMessage(
      domain: domain,
      code: code,
      description: desc,
    );
    throw ScreenCaptureKitException(
      message,
      domain: domain,
      code: code,
    );
  }

  return _parseShareableContent(json);
}

String _buildNativeErrorMessage({
  required String domain,
  required int code,
  required String description,
}) {
  final normalized = description.toLowerCase();
  final isTimeout = normalized.contains('timed out');
  final isPermissionIssue =
      normalized.contains('not authorized') ||
      normalized.contains('permission') ||
      normalized.contains('denied');

  if (isTimeout) {
    return 'Timed out while requesting shareable content. '
        'Make sure Screen Recording permission is granted in '
        'System Settings > Privacy & Security > Screen Recording, '
        'then retry.';
  }

  if (isPermissionIssue) {
    return 'Screen Recording permission is required to access '
        'shareable content. Grant permission in System Settings > '
        'Privacy & Security > Screen Recording, then restart the '
        'app and retry. [native: $domain ($code) $description]';
  }

  return 'Failed to retrieve shareable content. '
      '[native: $domain ($code) $description]';
}

String _buildStreamErrorMessage({
  required String domain,
  required int code,
  required String description,
}) {
  final normalized = description.toLowerCase();
  final isPermissionIssue =
      normalized.contains('not authorized') ||
      normalized.contains('permission') ||
      normalized.contains('denied') ||
      normalized.contains('user declined');

  if (isPermissionIssue) {
    return 'Failed to start capture stream. Screen Recording permission '
        'is required. Grant it in System Settings > Privacy & Security '
        '> Screen Recording, then restart the app and retry. '
        '[native: $domain ($code) $description]';
  }

  return 'Failed to start capture stream. '
      '[native: $domain ($code) $description]';
}

ShareableContent _parseShareableContent(Map<String, dynamic> json) {
  final displays = <Display>[];
  for (final d in json['displays'] as List<dynamic>? ?? []) {
    final m = d as Map<String, dynamic>;
    displays.add(
      Display(
        displayId: DisplayId((m['displayId'] as num).toInt()),
        size: FrameSize(
          width: (m['width'] as num).toInt(),
          height: (m['height'] as num).toInt(),
        ),
        refreshRate: DisplayRefreshRate.fromNum(m['refreshRate'] as num?),
      ),
    );
  }

  final applications = <RunningApplication>[];
  for (final a in json['applications'] as List<dynamic>? ?? []) {
    final m = a as Map<String, dynamic>;
    applications.add(
      RunningApplication(
        bundleIdentifier: BundleId(m['bundleIdentifier'] as String? ?? ''),
        applicationName: m['applicationName'] as String? ?? '',
        processId: ProcessId((m['processId'] as num).toInt()),
      ),
    );
  }

  final windows = <Window>[];
  for (final w in json['windows'] as List<dynamic>? ?? []) {
    final m = w as Map<String, dynamic>;
    final appJson = m['owningApplication'] as Map<String, dynamic>? ?? {};
    final frameJson = m['frame'] as Map<String, dynamic>? ?? {};
    windows.add(
      Window(
        windowId: WindowId((m['windowId'] as num).toInt()),
        frame: PixelRect(
          x: (frameJson['x'] as num?)?.toDouble() ?? 0,
          y: (frameJson['y'] as num?)?.toDouble() ?? 0,
          width: (frameJson['width'] as num?)?.toDouble() ?? 0,
          height: (frameJson['height'] as num?)?.toDouble() ?? 0,
        ),
        owningApplication: RunningApplication(
          bundleIdentifier: BundleId(
            appJson['bundleIdentifier'] as String? ?? '',
          ),
          applicationName: appJson['applicationName'] as String? ?? '',
          processId: ProcessId((appJson['processId'] as num?)?.toInt() ?? 0),
        ),
        title: m['title'] as String?,
      ),
    );
  }

  return ShareableContent(
    displays: displays,
    applications: applications,
    windows: windows,
  );
}

FilterId createWindowFilterImpl(Window window) {
  if (!Platform.isMacOS) {
    throw UnsupportedError(
      'screen_capture_kit only supports macOS. '
      'Current platform: ${Platform.operatingSystem}',
    );
  }

  final filterId = _createContentFilterForWindow(window.windowId.value);
  if (filterId <= 0) {
    throw ScreenCaptureKitException(
      'Failed to create content filter for window ${window.windowId.value}. '
      'The window may no longer exist or may not be capturable.',
    );
  }
  return FilterId(filterId);
}

FilterId createDisplayFilterImpl(
  Display display, {
  List<Window>? excludingWindows,
}) {
  if (!Platform.isMacOS) {
    throw UnsupportedError(
      'screen_capture_kit only supports macOS. '
      'Current platform: ${Platform.operatingSystem}',
    );
  }

  int filterId;
  if (excludingWindows != null && excludingWindows.isNotEmpty) {
    final windowIds = excludingWindows.map((w) => w.windowId.value).toList();
    final jsonStr = jsonEncode(windowIds);
    final units = utf8.encode(jsonStr);
    final ptr = malloc<Uint8>(units.length + 1);
    for (var i = 0; i < units.length; i++) {
      ptr[i] = units[i];
    }
    ptr[units.length] = 0;
    try {
      filterId = _createContentFilterForDisplayExcludingWindows(
        display.displayId.value,
        ptr.cast<Utf8>(),
      );
    } finally {
      malloc.free(ptr);
    }
  } else {
    filterId = _createContentFilterForDisplay(display.displayId.value);
  }

  if (filterId <= 0) {
    throw ScreenCaptureKitException(
      'Failed to create content filter for display ${display.displayId.value}. '
      'The display may not exist or may not be capturable.',
    );
  }
  return FilterId(filterId);
}

void releaseFilterImpl(FilterId handle) {
  if (!Platform.isMacOS) {
    return;
  }
  _releaseContentFilter(handle.filterId);
}

CapturedImage captureScreenshotImpl(
  FilterId filterHandle, {
  FrameSize frameSize = const FrameSize.zero(),
}) {
  if (!Platform.isMacOS) {
    throw UnsupportedError(
      'screen_capture_kit only supports macOS. '
      'Current platform: ${Platform.operatingSystem}',
    );
  }

  final ptr = _captureScreenshot(
    filterHandle.filterId,
    frameSize.width,
    frameSize.height,
  );
  if (ptr == nullptr) {
    throw const ScreenCaptureKitException(
      'Failed to capture screenshot from native bridge.',
    );
  }

  String jsonStr;
  try {
    jsonStr = ptr.toDartString();
  } finally {
    malloc.free(ptr);
  }

  final json = jsonDecode(jsonStr) as Map<String, dynamic>;

  if (json['error'] == true) {
    final domain = json['domain'] as String? ?? '';
    final code = json['code'] as int? ?? 0;
    final desc = json['localizedDescription'] as String? ?? '';
    final message = code == -3
        ? 'Screenshot capture requires macOS 14.0 or newer.'
        : 'Failed to capture screenshot. [native: $domain ($code) $desc]';
    throw ScreenCaptureKitException(message, domain: domain, code: code);
  }

  final base64 = json['pngBase64'] as String? ?? '';
  final pngData = base64.isNotEmpty
      ? Uint8List.fromList(base64Decode(base64))
      : Uint8List(0);
  final w = (json['width'] as num?)?.toInt() ?? 0;
  final h = (json['height'] as num?)?.toInt() ?? 0;

  return CapturedImage(
    pngData: pngData,
    size: FrameSize(width: w, height: h),
  );
}

FilterId? presentContentSharingPickerImpl({
  List<ContentSharingPickerMode>? allowedModes,
}) {
  if (!Platform.isMacOS) {
    throw UnsupportedError(
      'screen_capture_kit only supports macOS. '
      'Current platform: ${Platform.operatingSystem}',
    );
  }

  Pointer<Utf8> modesPtr = nullptr;
  if (allowedModes != null && allowedModes.isNotEmpty) {
    final names = allowedModes.map((m) {
      switch (m) {
        case ContentSharingPickerMode.singleDisplay:
          return 'singleDisplay';
        case ContentSharingPickerMode.singleWindow:
          return 'singleWindow';
        case ContentSharingPickerMode.singleApplication:
          return 'singleApplication';
        case ContentSharingPickerMode.multipleWindows:
          return 'multipleWindows';
        case ContentSharingPickerMode.multipleApplications:
          return 'multipleApplications';
      }
    }).toList();
    final jsonStr = jsonEncode(names);
    modesPtr = jsonStr.toNativeUtf8();
  }
  try {
    final ptr = _pickerPresent(modesPtr);
    if (ptr == nullptr) {
      return null;
    }
    String resultJson;
    try {
      resultJson = ptr.toDartString();
    } finally {
      malloc.free(ptr);
    }
    final json = jsonDecode(resultJson) as Map<String, dynamic>;
    if (json['error'] == true) {
      final domain = json['domain'] as String? ?? '';
      final code = json['code'] as int? ?? 0;
      final desc = json['localizedDescription'] as String? ?? '';
      final message = code == -3
          ? 'Content sharing picker requires macOS 14.0 or newer.'
          : 'Picker failed. [native: $domain ($code) $desc]';
      throw ScreenCaptureKitException(message, domain: domain, code: code);
    }
    if (json['cancelled'] == true) {
      return null;
    }
    final id = (json['filterId'] as num?)?.toInt() ?? 0;
    if (id <= 0) {
      return null;
    }
    return FilterId(id);
  } finally {
    if (modesPtr != nullptr) {
      malloc.free(modesPtr);
    }
  }
}

bool isContentSharingPickerActiveImpl() {
  if (!Platform.isMacOS) {
    return false;
  }
  return _pickerIsActive() != 0;
}

int contentSharingPickerMaximumStreamCountImpl() {
  if (!Platform.isMacOS) {
    return 0;
  }
  return _pickerMaximumStreamCount();
}

void streamSetPickerConfigurationImpl(
  int streamId,
  ContentSharingPickerConfiguration? config,
) {
  if (!Platform.isMacOS) {
    return;
  }
  if (config == null) {
    _streamSetPickerConfiguration(streamId, nullptr);
    return;
  }
  final map = <String, dynamic>{};
  if (config.allowedModes != null && config.allowedModes!.isNotEmpty) {
    map['allowedPickerModes'] = config.allowedModes!.map((m) {
      switch (m) {
        case ContentSharingPickerMode.singleDisplay:
          return 'singleDisplay';
        case ContentSharingPickerMode.singleWindow:
          return 'singleWindow';
        case ContentSharingPickerMode.singleApplication:
          return 'singleApplication';
        case ContentSharingPickerMode.multipleWindows:
          return 'multipleWindows';
        case ContentSharingPickerMode.multipleApplications:
          return 'multipleApplications';
      }
    }).toList();
  }
  if (config.allowsChangingSelectedContent != null) {
    map['allowsChangingSelectedContent'] = config.allowsChangingSelectedContent;
  }
  if (config.excludedBundleIds != null &&
      config.excludedBundleIds!.isNotEmpty) {
    map['excludedBundleIDs'] = config.excludedBundleIds!
        .map((id) => id.value)
        .toList();
  }
  if (config.excludedWindowIds != null &&
      config.excludedWindowIds!.isNotEmpty) {
    map['excludedWindowIDs'] = config.excludedWindowIds!
        .map((id) => id.value)
        .toList();
  }
  final jsonStr = jsonEncode(map);
  final ptr = jsonStr.toNativeUtf8();
  try {
    _streamSetPickerConfiguration(streamId, ptr);
  } finally {
    malloc.free(ptr);
  }
}

/// Reads a raw-frame buffer from native (16-byte header + BGRA pixels).
/// Returns null when no frame is available within [timeoutMs].
CapturedFrame? _getNextRawFrame(int streamId, int timeoutMs) {
  final ptr = _streamGetNextFrame(streamId, timeoutMs);
  if (ptr == nullptr) {
    return null;
  }
  try {
    final header = ptr.cast<Int32>();
    final w = header[0];
    final h = header[1];
    final bpr = header[2];
    final dataSize = header[3];
    if (dataSize <= 0 || w <= 0 || h <= 0) {
      return null;
    }
    final dataPtr = ptr.cast<Uint8>() + 16;
    final bgraData = Uint8List.fromList(dataPtr.asTypedList(dataSize));
    return CapturedFrame(
      bgraData: bgraData,
      size: FrameSize(width: w, height: h),
      bytesPerRow: bpr,
    );
  } finally {
    malloc.free(ptr);
  }
}

const _kMaxVideoFramesPerPollBatch = 64;

/// Batch-drain scheduler: pulls up to [_kMaxVideoFramesPerPollBatch] raw frames
/// per event-loop tick, yielding between batches so the Dart event loop stays
/// responsive.
void _scheduleVideoFramePolling({
  required int streamId,
  required StreamController<CapturedFrame> controller,
}) {
  void poll({bool resumeDrain = false}) {
    if (!controller.hasListener) {
      return;
    }

    var frame = _getNextRawFrame(streamId, resumeDrain ? 0 : 1);
    var drained = 0;
    var hitBatchLimit = false;

    while (frame != null && controller.hasListener) {
      controller.add(frame);
      drained++;
      if (drained >= _kMaxVideoFramesPerPollBatch) {
        hitBatchLimit = true;
        break;
      }
      frame = _getNextRawFrame(streamId, 0);
    }

    if (!controller.hasListener) {
      return;
    }

    if (hitBatchLimit) {
      Future.delayed(Duration.zero, () => poll(resumeDrain: true));
    } else {
      Future.delayed(const Duration(milliseconds: 1), poll);
    }
  }

  Future.delayed(Duration.zero, poll);
}

String? _getNextAudioJson(int streamId, int timeoutMs) {
  final ptr = _streamGetNextAudio(streamId, timeoutMs);
  if (ptr == nullptr) {
    return null;
  }
  try {
    return ptr.toDartString();
  } finally {
    malloc.free(ptr);
  }
}

String? _getNextMicrophoneJson(int streamId, int timeoutMs) {
  final ptr = _streamGetNextMicrophone(streamId, timeoutMs);
  if (ptr == nullptr) {
    return null;
  }
  try {
    return ptr.toDartString();
  } finally {
    malloc.free(ptr);
  }
}

CapturedAudio? _parseAudioJson(String jsonStr) {
  final json = jsonDecode(jsonStr) as Map<String, dynamic>;
  if (json['error'] == true) {
    return null;
  }
  final base64 = json['pcmBase64'] as String? ?? '';
  final pcmData = base64.isNotEmpty
      ? Uint8List.fromList(base64Decode(base64))
      : Uint8List(0);
  final sampleRate = (json['sampleRate'] as num?)?.toDouble() ?? 0.0;
  final channelCount = (json['channelCount'] as num?)?.toInt() ?? 0;
  final format = json['format'] as String? ?? 'raw';
  return CapturedAudio(
    pcmData: pcmData,
    sampleRate: sampleRate,
    channelCount: channelCount,
    format: format,
  );
}

Pointer<Utf8> _allocColorSpaceName(String? name) {
  if (name == null || name.isEmpty) {
    return nullptr;
  }
  final units = utf8.encode(name);
  final ptr = malloc<Uint8>(units.length + 1);
  for (var i = 0; i < units.length; i++) {
    ptr[i] = units[i];
  }
  ptr[units.length] = 0;
  return ptr.cast<Utf8>();
}

Stream<CapturedFrame> startCaptureStreamImpl(
  FilterId filterHandle, {
  FrameSize frameSize = const FrameSize.zero(),
  FrameRate frameRate = const FrameRate.fps60(),
  PixelRect? sourceRect,
  bool showsCursor = true,
  QueueDepth queueDepth = const QueueDepth.depth5(),
  bool capturesAudio = false,
  bool excludesCurrentProcessAudio = false,
  bool captureMicrophone = false,
  int? pixelFormat,
  String? colorSpaceName,
}) {
  if (!Platform.isMacOS) {
    throw UnsupportedError(
      'screen_capture_kit only supports macOS. '
      'Current platform: ${Platform.operatingSystem}',
    );
  }

  final src = sourceRect;
  final depth = queueDepth;
  final colorSpacePtr = _allocColorSpaceName(colorSpaceName);
  int streamId;
  try {
    streamId = _streamCreateAndStart(
      filterHandle.filterId,
      frameSize.width,
      frameSize.height,
      frameRate.value,
      src?.x ?? 0,
      src?.y ?? 0,
      src?.width ?? 0,
      src?.height ?? 0,
      showsCursor ? 1 : 0,
      depth.value,
      capturesAudio ? 1 : 0,
      excludesCurrentProcessAudio ? 1 : 0,
      captureMicrophone ? 1 : 0,
      pixelFormat ?? 0,
      colorSpacePtr,
    );
    if (streamId <= 0) {
      final ptr = _streamGetLastError();
      if (ptr != nullptr) {
        try {
          final jsonStr = ptr.toDartString();
          final json = jsonDecode(jsonStr) as Map<String, dynamic>;
          if (json['error'] == true) {
            final domain = json['domain'] as String? ?? '';
            final code = (json['code'] as num?)?.toInt() ?? 0;
            final desc = json['localizedDescription'] as String? ?? '';
            final message = _buildStreamErrorMessage(
              domain: domain,
              code: code,
              description: desc,
            );
            throw ScreenCaptureKitException(
              message,
              domain: domain,
              code: code,
            );
          }
        } finally {
          malloc.free(ptr);
        }
      }
      throw const ScreenCaptureKitException(
        'Failed to start capture stream. '
        'Check Screen Recording permission.',
      );
    }
  } finally {
    if (colorSpacePtr != nullptr) {
      malloc.free(colorSpacePtr);
    }
  }

  late final StreamController<CapturedFrame> controller;
  controller = StreamController<CapturedFrame>(
    onListen: () {
      _scheduleVideoFramePolling(
        streamId: streamId,
        controller: controller,
      );
    },
    onCancel: () {
      _streamStopAndRelease(streamId);
      unawaited(controller.close());
    },
  );
  return controller.stream;
}

void streamUpdateConfigurationImpl(int streamId, StreamConfiguration options) {
  final src = options.sourceRect;
  final depth = options.queueDepth.value;
  final colorSpacePtr = _allocColorSpaceName(options.colorSpaceName);
  try {
    final result = _streamUpdateConfiguration(
      streamId,
      options.frameSize.width,
      options.frameSize.height,
      options.frameRate.value,
      src?.x ?? 0,
      src?.y ?? 0,
      src?.width ?? 0,
      src?.height ?? 0,
      options.showsCursor ? 1 : 0,
      depth,
      options.capturesAudio ? 1 : 0,
      options.excludesCurrentProcessAudio ? 1 : 0,
      options.captureMicrophone ? 1 : 0,
      options.pixelFormat ?? 0,
      colorSpacePtr,
    );
    if (result != 0) {
      final ptr = _streamGetLastError();
      if (ptr != nullptr) {
        try {
          final jsonStr = ptr.toDartString();
          final json = jsonDecode(jsonStr) as Map<String, dynamic>;
          if (json['error'] == true) {
            final domain = json['domain'] as String? ?? '';
            final code = (json['code'] as num?)?.toInt() ?? 0;
            final desc = json['localizedDescription'] as String? ?? '';
            final message = _buildStreamErrorMessage(
              domain: domain,
              code: code,
              description: desc,
            );
            throw ScreenCaptureKitException(
              message,
              domain: domain,
              code: code,
            );
          }
        } finally {
          malloc.free(ptr);
        }
      }
      throw const ScreenCaptureKitException(
        'Failed to update stream configuration.',
      );
    }
  } finally {
    if (colorSpacePtr != nullptr) {
      malloc.free(colorSpacePtr);
    }
  }
}

void streamUpdateContentFilterImpl(
  int streamId,
  FilterId handle,
) {
  final result = _streamUpdateContentFilter(streamId, handle.filterId);
  if (result != 0) {
    final ptr = _streamGetLastError();
    if (ptr != nullptr) {
      try {
        final jsonStr = ptr.toDartString();
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        if (json['error'] == true) {
          final domain = json['domain'] as String? ?? '';
          final code = (json['code'] as num?)?.toInt() ?? 0;
          final desc = json['localizedDescription'] as String? ?? '';
          final message = _buildStreamErrorMessage(
            domain: domain,
            code: code,
            description: desc,
          );
          throw ScreenCaptureKitException(
            message,
            domain: domain,
            code: code,
          );
        }
      } finally {
        malloc.free(ptr);
      }
    }
    throw const ScreenCaptureKitException(
      'Failed to update stream content filter.',
    );
  }
}

CaptureStream startCaptureStreamWithUpdaterImpl(
  FilterId filterHandle, {
  FrameSize frameSize = const FrameSize.zero(),
  FrameRate frameRate = const FrameRate.fps60(),
  PixelRect? sourceRect,
  bool showsCursor = true,
  QueueDepth queueDepth = const QueueDepth.depth5(),
  bool capturesAudio = false,
  bool excludesCurrentProcessAudio = false,
  bool captureMicrophone = false,
  int? pixelFormat,
  String? colorSpaceName,
}) {
  if (!Platform.isMacOS) {
    throw UnsupportedError(
      'screen_capture_kit only supports macOS. '
      'Current platform: ${Platform.operatingSystem}',
    );
  }

  final src = sourceRect;
  final depth = queueDepth;
  final colorSpacePtr = _allocColorSpaceName(colorSpaceName);
  int streamId;
  try {
    streamId = _streamCreateAndStart(
      filterHandle.filterId,
      frameSize.width,
      frameSize.height,
      frameRate.value,
      src?.x ?? 0,
      src?.y ?? 0,
      src?.width ?? 0,
      src?.height ?? 0,
      showsCursor ? 1 : 0,
      depth.value,
      capturesAudio ? 1 : 0,
      excludesCurrentProcessAudio ? 1 : 0,
      captureMicrophone ? 1 : 0,
      pixelFormat ?? 0,
      colorSpacePtr,
    );
    if (streamId <= 0) {
      final ptr = _streamGetLastError();
      if (ptr != nullptr) {
        try {
          final jsonStr = ptr.toDartString();
          final json = jsonDecode(jsonStr) as Map<String, dynamic>;
          if (json['error'] == true) {
            final domain = json['domain'] as String? ?? '';
            final code = (json['code'] as num?)?.toInt() ?? 0;
            final desc = json['localizedDescription'] as String? ?? '';
            final message = _buildStreamErrorMessage(
              domain: domain,
              code: code,
              description: desc,
            );
            throw ScreenCaptureKitException(
              message,
              domain: domain,
              code: code,
            );
          }
        } finally {
          malloc.free(ptr);
        }
      }
      throw const ScreenCaptureKitException(
        'Failed to start capture stream. '
        'Check Screen Recording permission.',
      );
    }
  } finally {
    if (colorSpacePtr != nullptr) {
      malloc.free(colorSpacePtr);
    }
  }

  StreamController<CapturedAudio>? audioController;
  if (capturesAudio) {
    // Closed in onCancel when stream subscription is cancelled.
    // ignore: close_sinks
    late final StreamController<CapturedAudio> ac;
    ac = StreamController<CapturedAudio>(
      onListen: () {
        void pollAudio() {
          if (!ac.hasListener) {
            return;
          }
          final jsonStr = _getNextAudioJson(streamId, 100);
          if (jsonStr != null && ac.hasListener) {
            final audio = _parseAudioJson(jsonStr);
            if (audio != null) {
              ac.add(audio);
            }
          }
          if (ac.hasListener) {
            Future.delayed(const Duration(milliseconds: 1), pollAudio);
          }
        }

        Future.delayed(Duration.zero, pollAudio);
      },
    );
    audioController = ac;
  }

  StreamController<CapturedAudio>? microphoneController;
  if (captureMicrophone) {
    // Closed in onCancel when stream subscription is cancelled.
    late final StreamController<CapturedAudio> mc; // ignore: close_sinks
    mc = StreamController<CapturedAudio>(
      onListen: () {
        void pollMic() {
          if (!mc.hasListener) {
            return;
          }
          final jsonStr = _getNextMicrophoneJson(streamId, 100);
          if (jsonStr != null && mc.hasListener) {
            final audio = _parseAudioJson(jsonStr);
            if (audio != null) {
              mc.add(audio);
            }
          }
          if (mc.hasListener) {
            Future.delayed(const Duration(milliseconds: 1), pollMic);
          }
        }

        Future.delayed(Duration.zero, pollMic);
      },
    );
    microphoneController = mc;
  }

  late final StreamController<CapturedFrame> controller;
  controller = StreamController<CapturedFrame>(
    onListen: () {
      _scheduleVideoFramePolling(
        streamId: streamId,
        controller: controller,
      );
    },
    onCancel: () {
      _streamStopAndRelease(streamId);
      unawaited(controller.close());
      final ac = audioController;
      if (ac != null) {
        unawaited(ac.close());
      }
      final mc = microphoneController;
      if (mc != null) {
        unawaited(mc.close());
      }
    },
  );

  return CaptureStream(
    stream: controller.stream,
    audioStream: audioController?.stream,
    microphoneStream: microphoneController?.stream,
    updateConfiguration: (options) =>
        streamUpdateConfigurationImpl(streamId, options),
    updateContentFilter: (handle) =>
        streamUpdateContentFilterImpl(streamId, handle),
    setContentSharingPickerConfiguration: (config) =>
        streamSetPickerConfigurationImpl(streamId, config),
  );
}
