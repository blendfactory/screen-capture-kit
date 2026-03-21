import 'package:screen_capture_kit/screen_capture_kit.dart';
import 'package:test/test.dart';

void main() {
  group('ContentSharingPickerMode', () {
    test('has expected enum values', () {
      expect(ContentSharingPickerMode.values.length, 5);
      expect(
        ContentSharingPickerMode.values,
        contains(ContentSharingPickerMode.singleDisplay),
      );
      expect(
        ContentSharingPickerMode.values,
        contains(ContentSharingPickerMode.singleWindow),
      );
    });
  });
}
