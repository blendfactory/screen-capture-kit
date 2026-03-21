import 'package:screen_capture_kit/screen_capture_kit.dart';
import 'package:test/test.dart';

void main() {
  group('Display', () {
    test('equality', () {
      final a = Display(
        displayId: DisplayId(1),
        size: FrameSize(width: 1920, height: 1080),
      );
      final b = Display(
        displayId: DisplayId(1),
        size: FrameSize(width: 1920, height: 1080),
      );
      final c = Display(
        displayId: DisplayId(2),
        size: FrameSize(width: 1920, height: 1080),
      );
      final d = Display(
        displayId: DisplayId(1),
        size: FrameSize(width: 1920, height: 1080),
        refreshRate: DisplayRefreshRate(120),
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a, isNot(equals(d)));
    });
  });
}
