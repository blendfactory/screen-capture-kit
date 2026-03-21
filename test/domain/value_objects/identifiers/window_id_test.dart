import 'package:screen_capture_kit/screen_capture_kit.dart';
import 'package:test/test.dart';

void main() {
  group('WindowId', () {
    test('creates with positive id', () {
      expect(WindowId(100).value, 100);
    });

    test('rejects non-positive values', () {
      expect(() => WindowId(0), throwsArgumentError);
      expect(() => WindowId(-1), throwsArgumentError);
    });
  });
}
