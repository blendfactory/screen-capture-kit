import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'package:screen_capture_kit/src/captured_frame.dart';
import 'package:screen_capture_kit/src/captured_image.dart';
import 'package:screen_capture_kit/src/content_filter_handle.dart';
import 'package:screen_capture_kit/src/display.dart';
import 'package:screen_capture_kit/src/running_application.dart';
import 'package:screen_capture_kit/src/screen_capture_kit_exception.dart';
import 'package:screen_capture_kit/src/shareable_content.dart';
import 'package:screen_capture_kit/src/window.dart';

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
    )>(
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
);

@Native<Pointer<Utf8> Function(Int64, Int64)>(
  symbol: 'stream_get_next_frame',
  assetId: 'package:screen_capture_kit/screen_capture_kit.dart',
)
external Pointer<Utf8> _streamGetNextFrame(int streamId, int timeoutMs);

@Native<Void Function(Int64)>(
  symbol: 'stream_stop_and_release',
  assetId: 'package:screen_capture_kit/screen_capture_kit.dart',
)
external void _streamStopAndRelease(int streamId);

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
  final isPermissionIssue = normalized.contains('not authorized') ||
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

ShareableContent _parseShareableContent(Map<String, dynamic> json) {
  final displays = <Display>[];
  for (final d in json['displays'] as List<dynamic>? ?? []) {
    final m = d as Map<String, dynamic>;
    displays.add(
      Display(
        displayId: (m['displayId'] as num).toInt(),
        width: (m['width'] as num).toInt(),
        height: (m['height'] as num).toInt(),
      ),
    );
  }

  final applications = <RunningApplication>[];
  for (final a in json['applications'] as List<dynamic>? ?? []) {
    final m = a as Map<String, dynamic>;
    applications.add(
      RunningApplication(
        bundleIdentifier: m['bundleIdentifier'] as String? ?? '',
        applicationName: m['applicationName'] as String? ?? '',
        processId: (m['processId'] as num).toInt(),
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
        windowId: (m['windowId'] as num).toInt(),
        frame: (
          x: (frameJson['x'] as num?)?.toDouble() ?? 0,
          y: (frameJson['y'] as num?)?.toDouble() ?? 0,
          width: (frameJson['width'] as num?)?.toDouble() ?? 0,
          height: (frameJson['height'] as num?)?.toDouble() ?? 0,
        ),
        owningApplication: RunningApplication(
          bundleIdentifier: appJson['bundleIdentifier'] as String? ?? '',
          applicationName: appJson['applicationName'] as String? ?? '',
          processId: (appJson['processId'] as num?)?.toInt() ?? 0,
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

ContentFilterHandle createWindowFilterImpl(Window window) {
  if (!Platform.isMacOS) {
    throw UnsupportedError(
      'screen_capture_kit only supports macOS. '
      'Current platform: ${Platform.operatingSystem}',
    );
  }

  final filterId = _createContentFilterForWindow(window.windowId);
  if (filterId <= 0) {
    throw ScreenCaptureKitException(
      'Failed to create content filter for window ${window.windowId}. '
      'The window may no longer exist or may not be capturable.',
    );
  }
  return ContentFilterHandle(filterId);
}

ContentFilterHandle createDisplayFilterImpl(
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
    final windowIds = excludingWindows.map((w) => w.windowId).toList();
    final jsonStr = jsonEncode(windowIds);
    final units = utf8.encode(jsonStr);
    final ptr = malloc<Uint8>(units.length + 1);
    for (var i = 0; i < units.length; i++) {
      ptr[i] = units[i];
    }
    ptr[units.length] = 0;
    try {
      filterId = _createContentFilterForDisplayExcludingWindows(
        display.displayId,
        ptr.cast<Utf8>(),
      );
    } finally {
      malloc.free(ptr);
    }
  } else {
    filterId = _createContentFilterForDisplay(display.displayId);
  }

  if (filterId <= 0) {
    throw ScreenCaptureKitException(
      'Failed to create content filter for display ${display.displayId}. '
      'The display may not exist or may not be capturable.',
    );
  }
  return ContentFilterHandle(filterId);
}

void releaseFilterImpl(ContentFilterHandle handle) {
  if (!Platform.isMacOS) {
    return;
  }
  _releaseContentFilter(handle.filterId);
}

CapturedImage captureScreenshotImpl(
  ContentFilterHandle filterHandle, {
  int width = 0,
  int height = 0,
}) {
  if (!Platform.isMacOS) {
    throw UnsupportedError(
      'screen_capture_kit only supports macOS. '
      'Current platform: ${Platform.operatingSystem}',
    );
  }

  final ptr = _captureScreenshot(
    filterHandle.filterId,
    width,
    height,
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

  return CapturedImage(pngData: pngData, width: w, height: h);
}

/// Returns JSON string from native (sendable for Isolate.run). Caller parses.
String? _getNextFrameJson(int streamId, int timeoutMs) {
  final ptr = _streamGetNextFrame(streamId, timeoutMs);
  if (ptr == nullptr) {
    return null;
  }
  try {
    return ptr.toDartString();
  } finally {
    malloc.free(ptr);
  }
}

CapturedFrame? _parseFrameJson(String jsonStr) {
  final json = jsonDecode(jsonStr) as Map<String, dynamic>;
  if (json['error'] == true) {
    return null;
  }
  final base64 = json['bgraBase64'] as String? ?? '';
  final bgraData = base64.isNotEmpty
      ? Uint8List.fromList(base64Decode(base64))
      : Uint8List(0);
  final w = (json['width'] as num?)?.toInt() ?? 0;
  final h = (json['height'] as num?)?.toInt() ?? 0;
  final bpr = (json['bytesPerRow'] as num?)?.toInt() ?? 0;
  return CapturedFrame(
    bgraData: bgraData,
    width: w,
    height: h,
    bytesPerRow: bpr,
  );
}

Stream<CapturedFrame> startCaptureStreamImpl(
  ContentFilterHandle filterHandle, {
  int width = 0,
  int height = 0,
  int frameRate = 60,
  ({double x, double y, double width, double height})? sourceRect,
  bool showsCursor = true,
}) {
  if (!Platform.isMacOS) {
    throw UnsupportedError(
      'screen_capture_kit only supports macOS. '
      'Current platform: ${Platform.operatingSystem}',
    );
  }

  final src = sourceRect;
  final streamId = _streamCreateAndStart(
    filterHandle.filterId,
    width,
    height,
    frameRate,
    src?.x ?? 0,
    src?.y ?? 0,
    src?.width ?? 0,
    src?.height ?? 0,
    showsCursor ? 1 : 0,
  );
  if (streamId <= 0) {
    throw const ScreenCaptureKitException(
      'Failed to start capture stream. '
      'Check Screen Recording permission.',
    );
  }

  late final StreamController<CapturedFrame> controller;
  controller = StreamController<CapturedFrame>(
    onListen: () {
      // Poll with short timeout (100ms) so main thread can process events
      // between blocks. FFI may require main thread; long blocks cause SEGV.
      void poll() {
        if (!controller.hasListener) {
          return;
        }
        final jsonStr = _getNextFrameJson(streamId, 100);
        if (jsonStr != null && controller.hasListener) {
          final frame = _parseFrameJson(jsonStr);
          if (frame != null) {
            controller.add(frame);
          }
        }
        if (controller.hasListener) {
          Future.delayed(const Duration(milliseconds: 1), poll);
        }
      }

      Future.delayed(Duration.zero, poll);
    },
    onCancel: () {
      _streamStopAndRelease(streamId);
      unawaited(controller.close());
    },
  );
  return controller.stream;
}
