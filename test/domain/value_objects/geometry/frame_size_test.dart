import 'package:screen_capture_kit/screen_capture_kit.dart';
import 'package:test/test.dart';

void main() {
  group('FrameSize', () {
    test('zero is 0x0', () {
      expect(const FrameSize.zero().width, 0);
      expect(const FrameSize.zero().height, 0);
      expect(FrameSize.zero, returnsNormally);
    });

    test('factory rejects negative dimensions', () {
      expect(
        () => FrameSize(width: -1, height: 10),
        throwsArgumentError,
      );
    });

    test('factory rejects mixed zero and positive (capture output rule)', () {
      expect(
        () => FrameSize(width: 100, height: 0),
        throwsArgumentError,
      );
    });

    test('factory returns FrameSize.zero for 0x0', () {
      expect(FrameSize(width: 0, height: 0), const FrameSize.zero());
    });
  });
}
