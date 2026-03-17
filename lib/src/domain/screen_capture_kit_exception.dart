import 'package:meta/meta.dart';

/// Exception thrown when ScreenCaptureKit API fails.
@immutable
class ScreenCaptureKitException implements Exception {
  const ScreenCaptureKitException(
    this.message, {
    this.domain,
    this.code,
  });

  final String message;
  final String? domain;
  final int? code;

  @override
  String toString() {
    final details = [
      if (domain != null && domain!.isNotEmpty) domain,
      if (code != null) 'code=$code',
    ].join(', ');
    if (details.isEmpty) {
      return 'ScreenCaptureKitException: $message';
    }
    return 'ScreenCaptureKitException($details): $message';
  }
}
