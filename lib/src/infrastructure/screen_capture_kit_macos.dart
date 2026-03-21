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
import 'package:screen_capture_kit/src/domain/value_objects/capture/capture_resolution.dart';
import 'package:screen_capture_kit/src/domain/value_objects/capture/capture_stream_delegate_event.dart';
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
@Native<Pointer<Utf8> Function(Int64, Int32, Int32, Int32)>(
  symbol: 'capture_screenshot',
  assetId: 'package:screen_capture_kit/screen_capture_kit.dart',
)
external Pointer<Utf8> _captureScreenshot(
  int filterId,
  int width,
  int height,
  int captureResolution,
);

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
    Float,
    Float,
    Float,
    Float,
    Int32,
    Int32,
    Int32,
    Int32,
    Int32,
    Int32,
    Uint32,
    Pointer<Utf8>,
    Int32,
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
  int scalesToFit,
  double destX,
  double destY,
  double destWidth,
  double destHeight,
  int preservesAspectRatio,
  int showsCursor,
  int queueDepth,
  int capturesAudio,
  int excludesCurrentProcessAudio,
  int captureMicrophone,
  int pixelFormat,
  Pointer<Utf8> colorSpaceName,
  int captureResolution,
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

@Native<Pointer<Utf8> Function(Int64, Int64)>(
  symbol: 'stream_get_next_delegate_event',
  assetId: 'package:screen_capture_kit/screen_capture_kit.dart',
)
external Pointer<Utf8> _streamGetNextDelegateEvent(int streamId, int timeoutMs);

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
    Float,
    Float,
    Float,
    Float,
    Int32,
    Int32,
    Int32,
    Int32,
    Int32,
    Int32,
    Uint32,
    Pointer<Utf8>,
    Int32,
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
  int scalesToFit,
  double destX,
  double destY,
  double destWidth,
  double destHeight,
  int preservesAspectRatio,
  int showsCursor,
  int queueDepth,
  int capturesAudio,
  int excludesCurrentProcessAudio,
  int captureMicrophone,
  int pixelFormat,
  Pointer<Utf8> colorSpaceName,
  int captureResolution,
);

@Native<Int32 Function(Int64, Int64)>(
  symbol: 'stream_update_content_filter',
  assetId: 'package:screen_capture_kit/screen_capture_kit.dart',
)
external int _streamUpdateContentFilter(int streamId, int filterId);

/// Starts the system content-sharing picker asynchronously; poll until
/// non-null.
@Native<Int32 Function(Pointer<Utf8>)>(
  symbol: 'picker_start',
  assetId: 'package:screen_capture_kit/screen_capture_kit.dart',
)
external int _pickerStart(Pointer<Utf8> allowedModesJson);

/// Returns malloc'd JSON when ready, or nullptr if still pending.
@Native<Pointer<Utf8> Function()>(
  symbol: 'picker_poll',
  assetId: 'package:screen_capture_kit/screen_capture_kit.dart',
)
external Pointer<Utf8> _pickerPoll();

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
  _releaseContentFilter(handle.value);
}

CapturedImage captureScreenshotImpl(
  FilterId filterHandle, {
  FrameSize frameSize = const FrameSize.zero(),
  CaptureResolution captureResolution = CaptureResolution.automatic,
}) {
  if (!Platform.isMacOS) {
    throw UnsupportedError(
      'screen_capture_kit only supports macOS. '
      'Current platform: ${Platform.operatingSystem}',
    );
  }

  final ptr = _captureScreenshot(
    filterHandle.value,
    frameSize.width,
    frameSize.height,
    captureResolution.index,
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

Future<FilterId?> presentContentSharingPickerImpl({
  List<ContentSharingPickerMode>? allowedModes,
}) async {
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
    final startCode = _pickerStart(modesPtr);
    if (startCode == -1) {
      throw const ScreenCaptureKitException(
        'Content sharing picker session already in progress.',
        domain: 'ScreenCaptureKit',
        code: -1,
      );
    }
    final deadline = DateTime.now().add(const Duration(minutes: 5));
    Pointer<Utf8> ptr = nullptr;
    while (DateTime.now().isBefore(deadline)) {
      ptr = _pickerPoll();
      if (ptr != nullptr) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    if (ptr == nullptr) {
      throw const ScreenCaptureKitException(
        'Content sharing picker timed out waiting for result.',
        domain: 'ScreenCaptureKit',
        code: -1,
      );
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

/// Larger batches reduce risk of ScreenCaptureKit dropping microphone audio
/// when the Dart isolate briefly falls behind.
const _kMaxAudioChunksPerPollBatch = 96;

const _kMaxDelegateEventsPerPollBatch = 32;

/// When non-null, `SCStreamDelegate` events are delivered on this controller.
final Map<int, StreamController<CaptureStreamDelegateEvent>>
_delegateEventControllersByStreamId = {};

/// Latest frame and delegate controllers for a capture stream id. Updated on
/// every `_ensureCaptureOutputPolling` call so subscription order (delegate
/// vs video first) does not drop one side of the poll loop.
final Map<int, _CaptureOutputPollHandles> _captureOutputPollHandles = {};

/// Video + delegate output polling is active for this native stream id.
final Set<int> _captureOutputPollActive = {};

class _CaptureOutputPollHandles {
  StreamController<CapturedFrame>? frame;
  StreamController<CaptureStreamDelegateEvent>? delegate;
}

/// Owns a broadcast [StreamController] so [close] is explicit (satisfies
/// `close_sinks` for controllers created in
/// [startCaptureStreamWithUpdaterImpl]).
final class _BroadcastSink<T> {
  _BroadcastSink({void Function()? onListen})
    : _controller = StreamController<T>.broadcast(onListen: onListen);

  final StreamController<T> _controller;

  Stream<T> get stream => _controller.stream;

  StreamController<T> get controller => _controller;

  Future<void> close() => _controller.close();
}

/// Owns a single-subscription [StreamController] with explicit [close].
final class _AsyncStreamSink<T> {
  _AsyncStreamSink({void Function()? onListen, void Function()? onCancel})
    : _controller = StreamController<T>(
        onListen: onListen,
        onCancel: onCancel,
      );

  final StreamController<T> _controller;

  Stream<T> get stream => _controller.stream;

  StreamController<T> get controller => _controller;

  Future<void> close() => _controller.close();
}

/// Active capture stream IDs for unified system+mic polling (one event-loop
/// owner).
final _unifiedAudioPollActive = <int>{};

/// Batch-drain for PCM JSON chunks. Uses short native waits (never long blocks)
/// so system-audio polling cannot starve the microphone poller on the same
/// isolate.
void _scheduleCapturedAudioPolling({
  required int streamId,
  required StreamController<CapturedAudio> controller,
  required String? Function(int streamId, int timeoutMs) getNextJson,
}) {
  void poll({bool resumeDrain = false}) {
    if (!controller.hasListener) {
      return;
    }

    var jsonStr = getNextJson(streamId, resumeDrain ? 0 : 1);
    var drained = 0;
    var hitBatchLimit = false;

    while (jsonStr != null && controller.hasListener) {
      final audio = _parseAudioJson(jsonStr);
      if (audio != null) {
        controller.add(audio);
      }
      drained++;
      if (drained >= _kMaxAudioChunksPerPollBatch) {
        hitBatchLimit = true;
        break;
      }
      jsonStr = getNextJson(streamId, 0);
    }

    _drainDelegateEventsIfAudioPollOwnsStream(streamId);

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

/// One poll loop for **both** system and microphone when both streams are used.
/// Interleaves timeout-0 reads (fair round-robin) so neither stream monopolizes
/// the isolate; alternating 1 ms blocking reads avoid starving one native
/// queue.
void _ensureUnifiedSystemAndMicrophonePolling({
  required int streamId,
  required StreamController<CapturedAudio> system,
  required StreamController<CapturedAudio> microphone,
}) {
  if (_unifiedAudioPollActive.contains(streamId)) {
    return;
  }
  if (!system.hasListener && !microphone.hasListener) {
    return;
  }
  _unifiedAudioPollActive.add(streamId);

  /// Prefer blocking wait on mic when alternating: fewer native mic drops.
  var leadSystem = false;

  void poll({bool resumeDrain = false}) {
    if (!system.hasListener && !microphone.hasListener) {
      _unifiedAudioPollActive.remove(streamId);
      return;
    }

    var totalDrained = 0;
    var hitBatchLimit = false;

    while (totalDrained < _kMaxAudioChunksPerPollBatch) {
      var progressed = false;

      // Microphone first: system audio often yields larger bursts; mic backlogs
      // drop samples in ScreenCaptureKit if we fall behind.
      if (microphone.hasListener) {
        final jsonStr = _getNextMicrophoneJson(streamId, 0);
        if (jsonStr != null) {
          final audio = _parseAudioJson(jsonStr);
          if (audio != null) {
            microphone.add(audio);
          }
          totalDrained++;
          progressed = true;
          if (totalDrained >= _kMaxAudioChunksPerPollBatch) {
            hitBatchLimit = true;
            break;
          }
        }
      }

      if (hitBatchLimit) {
        break;
      }

      if (system.hasListener) {
        final jsonStr = _getNextAudioJson(streamId, 0);
        if (jsonStr != null) {
          final audio = _parseAudioJson(jsonStr);
          if (audio != null) {
            system.add(audio);
          }
          totalDrained++;
          progressed = true;
          if (totalDrained >= _kMaxAudioChunksPerPollBatch) {
            hitBatchLimit = true;
            break;
          }
        }
      }

      if (!progressed) {
        break;
      }
    }

    _drainDelegateEventsIfAudioPollOwnsStream(streamId);

    if (!system.hasListener && !microphone.hasListener) {
      _unifiedAudioPollActive.remove(streamId);
      return;
    }

    if (!resumeDrain && !hitBatchLimit) {
      const timeoutMs = 1;
      if (system.hasListener && microphone.hasListener) {
        if (leadSystem) {
          final jsonStr = _getNextAudioJson(streamId, timeoutMs);
          if (jsonStr != null) {
            final audio = _parseAudioJson(jsonStr);
            if (audio != null) {
              system.add(audio);
            }
          }
        } else {
          final jsonStr = _getNextMicrophoneJson(streamId, timeoutMs);
          if (jsonStr != null) {
            final audio = _parseAudioJson(jsonStr);
            if (audio != null) {
              microphone.add(audio);
            }
          }
        }
        leadSystem = !leadSystem;
      } else if (system.hasListener) {
        final jsonStr = _getNextAudioJson(streamId, timeoutMs);
        if (jsonStr != null) {
          final audio = _parseAudioJson(jsonStr);
          if (audio != null) {
            system.add(audio);
          }
        }
      } else if (microphone.hasListener) {
        final jsonStr = _getNextMicrophoneJson(streamId, timeoutMs);
        if (jsonStr != null) {
          final audio = _parseAudioJson(jsonStr);
          if (audio != null) {
            microphone.add(audio);
          }
        }
      }
    }

    if (!system.hasListener && !microphone.hasListener) {
      _unifiedAudioPollActive.remove(streamId);
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

/// Batch-drain scheduler: pulls video frames and/or `SCStreamDelegate` events.
///
/// [frameController] and [delegateController] are merged into
/// [_captureOutputPollHandles] so listeners can attach in any order (e.g.
/// delegate before video) without starving frames or delegate events.
void _ensureCaptureOutputPolling({
  required int streamId,
  StreamController<CapturedFrame>? frameController,
  StreamController<CaptureStreamDelegateEvent>? delegateController,
}) {
  final handles = _captureOutputPollHandles.putIfAbsent(
    streamId,
    _CaptureOutputPollHandles.new,
  );
  if (frameController != null) {
    handles.frame = frameController;
  }
  if (delegateController != null) {
    handles.delegate = delegateController;
  }

  if (_captureOutputPollActive.contains(streamId)) {
    return;
  }

  final wantVideo = handles.frame != null && handles.frame!.hasListener;
  final wantDelegate =
      handles.delegate != null && handles.delegate!.hasListener;
  if (!wantVideo && !wantDelegate) {
    return;
  }
  _captureOutputPollActive.add(streamId);

  void poll({bool resumeDrain = false}) {
    final h = _captureOutputPollHandles[streamId];
    if (h == null) {
      _captureOutputPollActive.remove(streamId);
      return;
    }

    final stillWantVideo = h.frame != null && h.frame!.hasListener;
    final stillWantDelegate = h.delegate != null && h.delegate!.hasListener;
    if (!stillWantVideo && !stillWantDelegate) {
      _captureOutputPollActive.remove(streamId);
      return;
    }

    var hitBatchLimit = false;

    if (stillWantVideo) {
      var frame = _getNextRawFrame(streamId, resumeDrain ? 0 : 1);
      var drained = 0;
      while (frame != null) {
        if (h.frame == null || !h.frame!.hasListener) {
          break;
        }
        h.frame!.add(frame);
        drained++;
        if (drained >= _kMaxVideoFramesPerPollBatch) {
          hitBatchLimit = true;
          break;
        }
        frame = _getNextRawFrame(streamId, 0);
      }
    }

    if (stillWantDelegate) {
      var delegateDrained = 0;
      while (true) {
        if (h.delegate == null || !h.delegate!.hasListener) {
          break;
        }
        final jsonStr = _getNextDelegateJson(streamId, 0);
        if (jsonStr == null) {
          break;
        }
        final ev = _parseDelegateEventJson(jsonStr);
        if (ev != null) {
          h.delegate!.add(ev);
        }
        delegateDrained++;
        if (delegateDrained >= _kMaxDelegateEventsPerPollBatch) {
          hitBatchLimit = true;
          break;
        }
      }
    }

    final h2 = _captureOutputPollHandles[streamId];
    if (h2 == null) {
      _captureOutputPollActive.remove(streamId);
      return;
    }
    final wantVideoAfter = h2.frame != null && h2.frame!.hasListener;
    final wantDelegateAfter = h2.delegate != null && h2.delegate!.hasListener;
    if (!wantVideoAfter && !wantDelegateAfter) {
      _captureOutputPollActive.remove(streamId);
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

void _drainDelegateEventsIfAudioPollOwnsStream(int streamId) {
  if (_delegateEventControllersByStreamId[streamId] == null ||
      !_delegateEventControllersByStreamId[streamId]!.hasListener) {
    return;
  }
  if (_captureOutputPollActive.contains(streamId)) {
    return;
  }
  for (var i = 0; i < _kMaxDelegateEventsPerPollBatch; i++) {
    final jsonStr = _getNextDelegateJson(streamId, 0);
    if (jsonStr == null) {
      break;
    }
    final ev = _parseDelegateEventJson(jsonStr);
    if (ev != null) {
      _delegateEventControllersByStreamId[streamId]!.add(ev);
    }
  }
}

String? _getNextDelegateJson(int streamId, int timeoutMs) {
  final ptr = _streamGetNextDelegateEvent(streamId, timeoutMs);
  if (ptr == nullptr) {
    return null;
  }
  try {
    return ptr.toDartString();
  } finally {
    malloc.free(ptr);
  }
}

CaptureStreamDelegateEvent? _parseDelegateEventJson(String jsonStr) {
  final json = jsonDecode(jsonStr) as Map<String, dynamic>;
  final type = json['type'] as String?;
  switch (type) {
    case 'didStopWithError':
      final domain = json['domain'] as String? ?? '';
      final code = (json['code'] as num?)?.toInt() ?? 0;
      final desc = json['localizedDescription'] as String? ?? '';
      final hasPayload = domain.isNotEmpty || code != 0 || desc.isNotEmpty;
      return CaptureStreamDelegateEvent.didStopWithError(
        errorDomain: hasPayload ? domain : null,
        errorCode: hasPayload ? code : null,
        errorDescription: hasPayload ? desc : null,
      );
    case 'outputVideoEffectDidStart':
      return const CaptureStreamDelegateEvent.outputVideoEffectDidStart();
    case 'outputVideoEffectDidStop':
      return const CaptureStreamDelegateEvent.outputVideoEffectDidStop();
    default:
      return null;
  }
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

/// When native sends `format: raw` (e.g. non-LinearPCM path), infer `f32` or
/// `s16` from buffer size and [numFrames] (`CMSampleBufferGetNumSamples`).
String _normalizeCapturedAudioFormat({
  required String format,
  required int channelCount,
  required Uint8List pcmData,
  required int? numFrames,
}) {
  if (format != 'raw') {
    return format;
  }
  if (pcmData.isEmpty || channelCount <= 0) {
    return 'f32';
  }
  if (numFrames == null || numFrames <= 0) {
    return 'f32';
  }
  final interleavedSamples = numFrames * channelCount;
  if (interleavedSamples == 0) {
    return 'f32';
  }
  if (pcmData.length % interleavedSamples != 0) {
    return 'f32';
  }
  final bytesPerSample = pcmData.length ~/ interleavedSamples;
  if (bytesPerSample == 4) {
    return 'f32';
  }
  if (bytesPerSample == 2) {
    return 's16';
  }
  return 'f32';
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
  final rawFormat = json['format'] as String? ?? 'raw';
  final frameCount = (json['numSamples'] as num?)?.toInt();
  final format = _normalizeCapturedAudioFormat(
    format: rawFormat,
    channelCount: channelCount,
    pcmData: pcmData,
    numFrames: frameCount,
  );
  final presentationTimeSeconds = (json['presentationTimeSeconds'] as num?)
      ?.toDouble();
  final durationSeconds = (json['durationSeconds'] as num?)?.toDouble();
  return CapturedAudio(
    pcmData: pcmData,
    sampleRate: sampleRate,
    channelCount: channelCount,
    format: format,
    frameCount: frameCount,
    presentationTimeSeconds: presentationTimeSeconds,
    durationSeconds: durationSeconds,
  );
}

/// Drains native audio/microphone JSON queues after Dart audio stream
/// listeners are canceled (poll loop stopped).
///
/// The SCStream may still be running; callbacks can refill queues. Unbounded
/// synchronous draining would starve the event loop and block timers (e.g.
/// `--duration`). Each pass is capped and yields between passes.
Future<void> _flushCaptureStreamPendingAudio({
  required int streamId,
  required bool captureSystem,
  required bool captureMicrophone,
  void Function(CapturedAudio chunk)? onSystemAudio,
  void Function(CapturedAudio chunk)? onMicrophoneAudio,
}) async {
  const maxPasses = 96;
  const maxChunksPerStreamPerPass = 4096;

  for (var pass = 0; pass < maxPasses; pass++) {
    var progressed = false;

    if (captureMicrophone && onMicrophoneAudio != null) {
      for (var i = 0; i < maxChunksPerStreamPerPass; i++) {
        final jsonStr = _getNextMicrophoneJson(streamId, 0);
        if (jsonStr == null) {
          break;
        }
        final audio = _parseAudioJson(jsonStr);
        if (audio != null) {
          onMicrophoneAudio(audio);
          progressed = true;
        }
      }
    }

    if (captureSystem && onSystemAudio != null) {
      for (var i = 0; i < maxChunksPerStreamPerPass; i++) {
        final jsonStr = _getNextAudioJson(streamId, 0);
        if (jsonStr == null) {
          break;
        }
        final audio = _parseAudioJson(jsonStr);
        if (audio != null) {
          onSystemAudio(audio);
          progressed = true;
        }
      }
    }

    if (!progressed) {
      break;
    }
    await Future<void>.delayed(Duration.zero);
  }
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
  bool? scalesToFit,
  PixelRect? destinationRect,
  bool? preservesAspectRatio,
  bool showsCursor = true,
  QueueDepth queueDepth = const QueueDepth.depth5(),
  bool capturesAudio = false,
  bool excludesCurrentProcessAudio = false,
  bool captureMicrophone = false,
  int? pixelFormat,
  String? colorSpaceName,
  CaptureResolution captureResolution = CaptureResolution.automatic,
}) {
  if (!Platform.isMacOS) {
    throw UnsupportedError(
      'screen_capture_kit only supports macOS. '
      'Current platform: ${Platform.operatingSystem}',
    );
  }

  final src = sourceRect;
  final scalesToFitParam = scalesToFit == null ? -1 : (scalesToFit ? 1 : 0);
  final preservesAspectRatioParam = preservesAspectRatio == null
      ? -1
      : (preservesAspectRatio ? 1 : 0);
  final dst = destinationRect;
  final depth = queueDepth;
  final colorSpacePtr = _allocColorSpaceName(colorSpaceName);
  int streamId;
  try {
    streamId = _streamCreateAndStart(
      filterHandle.value,
      frameSize.width,
      frameSize.height,
      frameRate.value,
      src?.x ?? 0,
      src?.y ?? 0,
      src?.width ?? 0,
      src?.height ?? 0,
      scalesToFitParam,
      dst?.x ?? 0,
      dst?.y ?? 0,
      dst?.width ?? 0,
      dst?.height ?? 0,
      preservesAspectRatioParam,
      showsCursor ? 1 : 0,
      depth.value,
      capturesAudio ? 1 : 0,
      excludesCurrentProcessAudio ? 1 : 0,
      captureMicrophone ? 1 : 0,
      pixelFormat ?? 0,
      colorSpacePtr,
      captureResolution.index,
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
      _ensureCaptureOutputPolling(
        streamId: streamId,
        frameController: controller,
      );
    },
    onCancel: () {
      _captureOutputPollActive.remove(streamId);
      _captureOutputPollHandles.remove(streamId);
      _streamStopAndRelease(streamId);
      unawaited(controller.close());
    },
  );
  return controller.stream;
}

void streamUpdateConfigurationImpl(int streamId, StreamConfiguration options) {
  final src = options.sourceRect;
  final dst = options.destinationRect;
  final depth = options.queueDepth.value;
  final scalesToFitValue = options.scalesToFit;
  final preservesAspectRatioValue = options.preservesAspectRatio;
  final scalesToFitParam = scalesToFitValue == null
      ? -1
      : (scalesToFitValue ? 1 : 0);
  final preservesAspectRatioParam = preservesAspectRatioValue == null
      ? -1
      : (preservesAspectRatioValue ? 1 : 0);
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
      scalesToFitParam,
      dst?.x ?? 0,
      dst?.y ?? 0,
      dst?.width ?? 0,
      dst?.height ?? 0,
      preservesAspectRatioParam,
      options.showsCursor ? 1 : 0,
      depth,
      options.capturesAudio ? 1 : 0,
      options.excludesCurrentProcessAudio ? 1 : 0,
      options.captureMicrophone ? 1 : 0,
      options.pixelFormat ?? 0,
      colorSpacePtr,
      options.captureResolution.index,
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
  final result = _streamUpdateContentFilter(streamId, handle.value);
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
  bool? scalesToFit,
  PixelRect? destinationRect,
  bool? preservesAspectRatio,
  bool showsCursor = true,
  QueueDepth queueDepth = const QueueDepth.depth5(),
  bool capturesAudio = false,
  bool excludesCurrentProcessAudio = false,
  bool captureMicrophone = false,
  int? pixelFormat,
  String? colorSpaceName,
  CaptureResolution captureResolution = CaptureResolution.automatic,
  bool emitDelegateEvents = false,
}) {
  if (!Platform.isMacOS) {
    throw UnsupportedError(
      'screen_capture_kit only supports macOS. '
      'Current platform: ${Platform.operatingSystem}',
    );
  }

  final src = sourceRect;
  final scalesToFitParam = scalesToFit == null ? -1 : (scalesToFit ? 1 : 0);
  final preservesAspectRatioParam = preservesAspectRatio == null
      ? -1
      : (preservesAspectRatio ? 1 : 0);
  final dst = destinationRect;
  final depth = queueDepth;
  final colorSpacePtr = _allocColorSpaceName(colorSpaceName);
  int streamId;
  try {
    streamId = _streamCreateAndStart(
      filterHandle.value,
      frameSize.width,
      frameSize.height,
      frameRate.value,
      src?.x ?? 0,
      src?.y ?? 0,
      src?.width ?? 0,
      src?.height ?? 0,
      scalesToFitParam,
      dst?.x ?? 0,
      dst?.y ?? 0,
      dst?.width ?? 0,
      dst?.height ?? 0,
      preservesAspectRatioParam,
      showsCursor ? 1 : 0,
      depth.value,
      capturesAudio ? 1 : 0,
      excludesCurrentProcessAudio ? 1 : 0,
      captureMicrophone ? 1 : 0,
      pixelFormat ?? 0,
      colorSpacePtr,
      captureResolution.index,
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

  _BroadcastSink<CaptureStreamDelegateEvent>? delegateSink;
  if (emitDelegateEvents) {
    late final _BroadcastSink<CaptureStreamDelegateEvent> dec;
    dec = _BroadcastSink<CaptureStreamDelegateEvent>(
      onListen: () {
        _ensureCaptureOutputPolling(
          streamId: streamId,
          delegateController: dec.controller,
        );
      },
    );
    delegateSink = dec;
    _delegateEventControllersByStreamId[streamId] = dec.controller;
  }

  _AsyncStreamSink<CapturedAudio>? audioSink;
  _AsyncStreamSink<CapturedAudio>? microphoneSink;

  if (capturesAudio && captureMicrophone) {
    late final _AsyncStreamSink<CapturedAudio> ac;
    late final _AsyncStreamSink<CapturedAudio> mc;
    ac = _AsyncStreamSink<CapturedAudio>(
      onListen: () {
        _ensureUnifiedSystemAndMicrophonePolling(
          streamId: streamId,
          system: ac.controller,
          microphone: mc.controller,
        );
      },
    );
    mc = _AsyncStreamSink<CapturedAudio>(
      onListen: () {
        _ensureUnifiedSystemAndMicrophonePolling(
          streamId: streamId,
          system: ac.controller,
          microphone: mc.controller,
        );
      },
    );
    audioSink = ac;
    microphoneSink = mc;
  } else if (capturesAudio) {
    late final _AsyncStreamSink<CapturedAudio> ac;
    ac = _AsyncStreamSink<CapturedAudio>(
      onListen: () {
        _scheduleCapturedAudioPolling(
          streamId: streamId,
          controller: ac.controller,
          getNextJson: _getNextAudioJson,
        );
      },
    );
    audioSink = ac;
  } else if (captureMicrophone) {
    late final _AsyncStreamSink<CapturedAudio> mc;
    mc = _AsyncStreamSink<CapturedAudio>(
      onListen: () {
        _scheduleCapturedAudioPolling(
          streamId: streamId,
          controller: mc.controller,
          getNextJson: _getNextMicrophoneJson,
        );
      },
    );
    microphoneSink = mc;
  }

  late final _AsyncStreamSink<CapturedFrame> frameSink;
  frameSink = _AsyncStreamSink<CapturedFrame>(
    onListen: () {
      _ensureCaptureOutputPolling(
        streamId: streamId,
        frameController: frameSink.controller,
        delegateController: delegateSink?.controller,
      );
    },
    onCancel: () {
      _unifiedAudioPollActive.remove(streamId);
      _captureOutputPollActive.remove(streamId);
      _captureOutputPollHandles.remove(streamId);
      _delegateEventControllersByStreamId.remove(streamId);
      _streamStopAndRelease(streamId);
      unawaited(frameSink.close());
      final as = audioSink;
      if (as != null) {
        unawaited(as.close());
      }
      final ms = microphoneSink;
      if (ms != null) {
        unawaited(ms.close());
      }
      final ds = delegateSink;
      if (ds != null) {
        unawaited(ds.close());
      }
    },
  );

  return CaptureStream(
    stream: frameSink.stream,
    audioStream: audioSink?.stream,
    microphoneStream: microphoneSink?.stream,
    delegateEvents: delegateSink?.stream,
    updateConfiguration: (options) =>
        streamUpdateConfigurationImpl(streamId, options),
    updateContentFilter: (handle) =>
        streamUpdateContentFilterImpl(streamId, handle),
    setContentSharingPickerConfiguration: (config) =>
        streamSetPickerConfigurationImpl(streamId, config),
    pendingAudioFlush: (capturesAudio || captureMicrophone)
        ? ({
            void Function(CapturedAudio chunk)? onSystemAudio,
            void Function(CapturedAudio chunk)? onMicrophoneAudio,
          }) => _flushCaptureStreamPendingAudio(
            streamId: streamId,
            captureSystem: capturesAudio,
            captureMicrophone: captureMicrophone,
            onSystemAudio: onSystemAudio,
            onMicrophoneAudio: onMicrophoneAudio,
          )
        : null,
  );
}
