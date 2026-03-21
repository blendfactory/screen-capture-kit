import 'package:screen_capture_kit/screen_capture_kit.dart';
import 'package:test/test.dart';

void main() {
  group('ContentFilter', () {
    test('ContentFilter.window creates with window', () {
      final app = RunningApplication(
        bundleIdentifier: const BundleId('com.example'),
        applicationName: 'Example',
        processId: ProcessId(1),
      );
      final window = Window(
        windowId: WindowId(100),
        frame: PixelRect(x: 0, y: 0, width: 800, height: 600),
        owningApplication: app,
      );
      final filter = ContentFilter.window(window);
      expect(filter, isA<ContentFilter>());
      expect(filter.toString(), contains('window'));
    });

    test('ContentFilter.display creates with display', () {
      final display = Display(
        displayId: DisplayId(1),
        size: FrameSize(width: 1920, height: 1080),
      );
      final filter = ContentFilter.display(display);
      expect(filter, isA<ContentFilter>());
      expect(filter.toString(), contains('display'));
    });

    test(
      'ContentFilter.displayExcludingWindows creates with display and list',
      () {
        final display = Display(
          displayId: DisplayId(1),
          size: FrameSize(width: 1920, height: 1080),
        );
        final app = RunningApplication(
          bundleIdentifier: const BundleId('com.example'),
          applicationName: 'Example',
          processId: ProcessId(1),
        );
        final window = Window(
          windowId: WindowId(100),
          frame: PixelRect(x: 0, y: 0, width: 100, height: 100),
          owningApplication: app,
        );
        final filter = ContentFilter.displayExcludingWindows(
          display,
          [window],
        );
        expect(filter, isA<ContentFilter>());
        expect(filter.toString(), contains('displayExcludingWindows'));
      },
    );

    test('ContentFilter.region creates with rect', () {
      final filter = ContentFilter.region(
        PixelRect(x: 10, y: 20, width: 400, height: 300),
      );
      expect(filter, isA<ContentFilter>());
      expect(filter.toString(), contains('region'));
    });
  });
}
