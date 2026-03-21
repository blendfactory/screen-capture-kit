import 'package:screen_capture_kit/screen_capture_kit.dart';
import 'package:test/test.dart';

void main() {
  group('CaptureResolution', () {
    test('values match native SCCaptureResolutionType order', () {
      expect(CaptureResolution.values.length, 3);
      expect(CaptureResolution.automatic.index, 0);
      expect(CaptureResolution.best.index, 1);
      expect(CaptureResolution.nominal.index, 2);
    });
  });
}
