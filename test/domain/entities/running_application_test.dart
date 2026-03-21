import 'package:screen_capture_kit/screen_capture_kit.dart';
import 'package:test/test.dart';

void main() {
  group('RunningApplication', () {
    test('creates with required fields', () {
      final app = RunningApplication(
        bundleIdentifier: const BundleId('com.example.app'),
        applicationName: 'Example',
        processId: ProcessId(1234),
      );
      expect(app.bundleIdentifier, const BundleId('com.example.app'));
      expect(app.applicationName, 'Example');
      expect(app.processId.value, 1234);
    });

    test('equality', () {
      final a = RunningApplication(
        bundleIdentifier: const BundleId('com.test'),
        applicationName: 'Test',
        processId: ProcessId(1),
      );
      final b = RunningApplication(
        bundleIdentifier: const BundleId('com.test'),
        applicationName: 'Test',
        processId: ProcessId(1),
      );
      expect(a, equals(b));
    });
  });
}
