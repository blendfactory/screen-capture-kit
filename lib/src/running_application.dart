import 'package:meta/meta.dart';

/// A running application available for capture.
///
/// Maps to [SCRunningApplication](https://developer.apple.com/documentation/screencapturekit/scrunningapplication).
@immutable
class RunningApplication {
  /// Creates a [RunningApplication] with the given properties.
  const RunningApplication({
    required this.bundleIdentifier,
    required this.applicationName,
    required this.processId,
  });

  /// The bundle identifier of the application.
  final String bundleIdentifier;

  /// The display name of the application.
  final String applicationName;

  /// The process ID.
  final int processId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RunningApplication &&
          runtimeType == other.runtimeType &&
          bundleIdentifier == other.bundleIdentifier &&
          applicationName == other.applicationName &&
          processId == other.processId;

  @override
  int get hashCode => Object.hash(bundleIdentifier, applicationName, processId);

  @override
  String toString() =>
      'RunningApplication(bundleIdentifier: $bundleIdentifier, '
      'applicationName: $applicationName, processId: $processId)';
}
