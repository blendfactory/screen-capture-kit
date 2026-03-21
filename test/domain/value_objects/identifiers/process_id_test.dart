import 'package:screen_capture_kit/screen_capture_kit.dart';
import 'package:test/test.dart';

void main() {
  group('ProcessId', () {
    test('creates with non-negative id', () {
      expect(ProcessId(0).value, 0);
      expect(ProcessId(1234).value, 1234);
    });

    test('rejects negative values', () {
      expect(() => ProcessId(-1), throwsArgumentError);
    });
  });
}
