import 'package:screen_capture_kit/screen_capture_kit.dart';
import 'package:test/test.dart';

void main() {
  group('ShareableContent', () {
    test('creates with empty lists', () {
      const content = ShareableContent(
        displays: [],
        applications: [],
        windows: [],
      );
      expect(content.displays, isEmpty);
      expect(content.applications, isEmpty);
      expect(content.windows, isEmpty);
    });

    test('creates with display data', () {
      final display = Display(
        displayId: DisplayId(1),
        size: FrameSize(width: 1920, height: 1080),
      );
      final content = ShareableContent(
        displays: [display],
        applications: const [],
        windows: const [],
      );
      expect(content.displays, hasLength(1));
      expect(content.displays.first.displayId.value, 1);
      expect(content.displays.first.width, 1920);
      expect(content.displays.first.height, 1080);
    });
  });
}
