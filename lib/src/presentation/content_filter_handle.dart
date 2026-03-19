/// @docImport 'package:screen_capture_kit/src/application/screen_capture_kit.dart';
library;

import 'package:meta/meta.dart';

import 'package:screen_capture_kit/src/domain/value_objects/filter_id.dart';

/// Opaque handle to a native SCContentFilter.
///
/// Created by [ScreenCaptureKitPort.createWindowFilter] or
/// [ScreenCaptureKitPort.createDisplayFilter]. Must be released
/// with [ScreenCaptureKitPort.releaseFilter] when no longer needed.
///
/// This handle will be used when implementing capture streams.
///
/// The underlying [FilterId] must have a value greater than 0; callers
/// (e.g. infrastructure) enforce this before construction.
@immutable
class ContentFilterHandle {
  const ContentFilterHandle(FilterId id) : _filterId = id;

  final FilterId _filterId;

  /// The underlying filter identifier for native calls.
  int get filterId => _filterId.value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContentFilterHandle && _filterId == other._filterId;

  @override
  int get hashCode => _filterId.hashCode;

  @override
  String toString() => 'ContentFilterHandle(${_filterId.value})';
}
