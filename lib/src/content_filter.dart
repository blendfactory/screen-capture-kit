import 'package:meta/meta.dart';
import 'package:screen_capture_kit/src/display.dart';
import 'package:screen_capture_kit/src/running_application.dart';
import 'package:screen_capture_kit/src/window.dart';

/// Configuration for which content a capture stream includes.
///
/// Maps to [SCContentFilter](https://developer.apple.com/documentation/screencapturekit/sccontentfilter).
///
/// Use [ContentFilter.window] for single-window capture,
/// [ContentFilter.display] for display capture with optional exclusions,
/// or [ContentFilter.displayExcludingWindows] for display minus specific windows.
@immutable
sealed class ContentFilter {
  const ContentFilter._();

  /// Creates a filter for capturing a single window.
  ///
  /// Captures only the specified window, independent of which display it's on.
  /// Maps to `SCContentFilter(desktopIndependentWindow:)`.
  ///
  /// Ref: https://developer.apple.com/documentation/screencapturekit/sccontentfilter/3944912-init
  factory ContentFilter.window(Window window) = _WindowContentFilter;

  /// Creates a filter for capturing a display with optional exclusions.
  ///
  /// [excludingApplications] excludes these apps from capture.
  /// [exceptingWindows] includes these windows even if their app is excluded.
  /// Maps to `SCContentFilter(display:excludingApplications:exceptingWindows:)`.
  ///
  /// Ref: https://developer.apple.com/documentation/screencapturekit/sccontentfilter/3944911-init
  factory ContentFilter.display(
    Display display, {
    List<RunningApplication>? excludingApplications,
    List<Window>? exceptingWindows,
  }) = _DisplayContentFilter;

  /// Creates a filter for capturing a display excluding specific windows.
  ///
  /// Maps to `SCContentFilter(display:excludingWindows:)`.
  ///
  /// Ref: https://developer.apple.com/documentation/screencapturekit/sccontentfilter/3944910-init
  factory ContentFilter.displayExcludingWindows(
    Display display,
    List<Window> excludingWindows,
  ) = _DisplayExcludingWindowsContentFilter;

  /// Creates a filter for capturing a rectangular region.
  ///
  /// [rect] is in screen points (x, y, width, height).
  /// Requires a base display filter; use [ContentFilter.display] first,
  /// then set contentRect. For now this is a standalone filter that
  /// captures a region of the main display.
  ///
  /// Maps to `SCContentFilter.contentRect`.
  factory ContentFilter.region(({double x, double y, double width, double height}) rect) =
      _RegionContentFilter;
}

/// Filter for single-window capture.
@immutable
final class _WindowContentFilter extends ContentFilter {
  _WindowContentFilter(this.window) : super._();

  final Window window;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _WindowContentFilter && window == other.window;

  @override
  int get hashCode => window.hashCode;

  @override
  String toString() => 'ContentFilter.window($window)';
}

/// Filter for display capture with app/window exclusions.
@immutable
final class _DisplayContentFilter extends ContentFilter {
  _DisplayContentFilter(
    this.display, {
    List<RunningApplication>? excludingApplications,
    List<Window>? exceptingWindows,
  })  : excludingApplications = excludingApplications ?? const [],
        exceptingWindows = exceptingWindows ?? const [],
        super._();

  final Display display;
  final List<RunningApplication> excludingApplications;
  final List<Window> exceptingWindows;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _DisplayContentFilter &&
          display == other.display &&
          _listEquals(excludingApplications, other.excludingApplications) &&
          _listEquals(exceptingWindows, other.exceptingWindows);

  @override
  int get hashCode =>
      Object.hash(display, Object.hashAll(excludingApplications), Object.hashAll(exceptingWindows));

  @override
  String toString() =>
      'ContentFilter.display($display, excluding: ${excludingApplications.length}, excepting: ${exceptingWindows.length})';
}

/// Filter for display capture excluding specific windows.
@immutable
final class _DisplayExcludingWindowsContentFilter extends ContentFilter {
  _DisplayExcludingWindowsContentFilter(this.display, this.excludingWindows)
      : super._();

  final Display display;
  final List<Window> excludingWindows;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _DisplayExcludingWindowsContentFilter &&
          display == other.display &&
          _listEquals(excludingWindows, other.excludingWindows);

  @override
  int get hashCode => Object.hash(display, Object.hashAll(excludingWindows));

  @override
  String toString() =>
      'ContentFilter.displayExcludingWindows($display, ${excludingWindows.length} windows)';
}

/// Filter for rectangular region capture.
@immutable
final class _RegionContentFilter extends ContentFilter {
  _RegionContentFilter(this.rect) : super._();

  final ({double x, double y, double width, double height}) rect;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _RegionContentFilter &&
          rect.x == other.rect.x &&
          rect.y == other.rect.y &&
          rect.width == other.rect.width &&
          rect.height == other.rect.height;

  @override
  int get hashCode => Object.hash(rect.x, rect.y, rect.width, rect.height);

  @override
  String toString() => 'ContentFilter.region($rect)';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
