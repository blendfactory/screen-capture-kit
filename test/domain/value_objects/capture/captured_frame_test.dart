import 'dart:typed_data';

import 'package:screen_capture_kit/screen_capture_kit.dart';
import 'package:test/test.dart';

void main() {
  group('CapturedFrame', () {
    test('creates with required fields', () {
      final frame = CapturedFrame(
        bgraData: Uint8List.fromList([1, 2, 3, 4]),
        size: FrameSize(width: 10, height: 5),
        bytesPerRow: 40,
      );
      expect(frame.bgraData.length, 4);
      expect(frame.size.width, 10);
      expect(frame.size.height, 5);
      expect(frame.bytesPerRow, 40);
    });
  });
}
