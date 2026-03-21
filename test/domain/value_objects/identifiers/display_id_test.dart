import 'package:screen_capture_kit/screen_capture_kit.dart';
import 'package:test/test.dart';

void main() {
  group('DisplayId', () {
    test('creates with positive id', () {
      expect(DisplayId(1).value, 1);
    });

    test('rejects non-positive values', () {
      expect(() => DisplayId(0), throwsArgumentError);
      expect(() => DisplayId(-1), throwsArgumentError);
    });
  });
}
