import 'package:screen_capture_kit/screen_capture_kit.dart';
import 'package:test/test.dart';

void main() {
  group('PixelRect', () {
    test('creates with finite non-negative size', () {
      final r = PixelRect(x: 1, y: -2, width: 3, height: 4);
      expect(r.x, 1);
      expect(r.y, -2);
      expect(r.width, 3);
      expect(r.height, 4);
    });

    test('allows zero width or height', () {
      expect(PixelRect(x: 0, y: 0, width: 0, height: 0).width, 0);
    });

    test('rejects non-finite components', () {
      expect(
        () => PixelRect(x: double.nan, y: 0, width: 1, height: 1),
        throwsArgumentError,
      );
      expect(
        () => PixelRect(x: 0, y: 0, width: double.infinity, height: 1),
        throwsArgumentError,
      );
    });

    test('rejects negative width or height', () {
      expect(
        () => PixelRect(x: 0, y: 0, width: -1, height: 1),
        throwsArgumentError,
      );
      expect(
        () => PixelRect(x: 0, y: 0, width: 1, height: -1),
        throwsArgumentError,
      );
    });
  });
}
