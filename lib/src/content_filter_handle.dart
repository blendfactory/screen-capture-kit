import 'package:meta/meta.dart';

/// Opaque handle to a native SCContentFilter.
///
/// Created by [ScreenCaptureKit.createWindowFilter]. Must be released with
/// [ScreenCaptureKit.releaseFilter] when no longer needed.
///
/// This handle will be used when implementing capture streams.
@immutable
class ContentFilterHandle {
  ContentFilterHandle(this._filterId) : assert(_filterId > 0, 'Invalid filter id');

  final int _filterId;

  int get filterId => _filterId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContentFilterHandle && _filterId == other._filterId;

  @override
  int get hashCode => _filterId.hashCode;

  @override
  String toString() => 'ContentFilterHandle($_filterId)';
}
