import 'dart:typed_data';

import 'package:screen_capture_kit/screen_capture_kit.dart';
import 'package:test/test.dart';

void main() {
  group('CapturedImage', () {
    test('creates with required fields', () {
      final image = CapturedImage(
        pngData: Uint8List.fromList([0x89, 0x50, 0x4e]),
        size: FrameSize(width: 100, height: 50),
      );
      expect(image.pngData.length, 3);
      expect(image.width, 100);
      expect(image.height, 50);
    });
  });
}
