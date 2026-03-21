import 'package:screen_capture_kit/screen_capture_kit.dart';
import 'package:test/test.dart';

void main() {
  group('FilterId', () {
    test('creates with positive filter id', () {
      final filterId = FilterId(1);
      expect(filterId.value, 1);
    });

    test('rejects non-positive values', () {
      expect(() => FilterId(0), throwsArgumentError);
      expect(() => FilterId(-1), throwsArgumentError);
    });
  });
}
