import 'package:screen_capture_kit/screen_capture_kit.dart';
import 'package:test/test.dart';

void main() {
  group('Window', () {
    test('creates with frame and owning app', () {
      const app = RunningApplication(
        bundleIdentifier: BundleId('com.example'),
        applicationName: 'Example',
        processId: ProcessId(1),
      );
      const window = Window(
        windowId: WindowId(100),
        frame: PixelRect(x: 0, y: 0, width: 800, height: 600),
        owningApplication: app,
        title: 'Test Window',
      );
      expect(window.windowId.value, 100);
      expect(window.frame.width, 800);
      expect(window.frame.height, 600);
      expect(
        window.owningApplication.bundleIdentifier,
        const BundleId('com.example'),
      );
      expect(window.title, 'Test Window');
    });
  });
}
