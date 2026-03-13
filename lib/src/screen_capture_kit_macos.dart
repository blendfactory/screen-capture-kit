import 'dart:convert';
import 'dart:ffi';
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';

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

@Native<Void Function(Int64)>(
  symbol: 'release_content_filter',
  assetId: 'package:screen_capture_kit/screen_capture_kit.dart',
)
external void _releaseContentFilter(int filterId);

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

void releaseFilterImpl(ContentFilterHandle handle) {
  if (!Platform.isMacOS) {
    return;
  }
  _releaseContentFilter(handle.filterId);
}
