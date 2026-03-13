// Tests intentionally print caught exceptions for visibility when run.
// ignore_for_file: avoid_print

import 'dart:async';

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
      const display = Display(
        displayId: 1,
        width: 1920,
        height: 1080,
      );
      const content = ShareableContent(
        displays: [display],
        applications: [],
        windows: [],
      );
      expect(content.displays, hasLength(1));
      expect(content.displays.first.displayId, 1);
      expect(content.displays.first.width, 1920);
      expect(content.displays.first.height, 1080);
    });

    test('Display equality', () {
      const a = Display(displayId: 1, width: 1920, height: 1080);
      const b = Display(displayId: 1, width: 1920, height: 1080);
      const c = Display(displayId: 2, width: 1920, height: 1080);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('RunningApplication', () {
    test('creates with required fields', () {
      const app = RunningApplication(
        bundleIdentifier: 'com.example.app',
        applicationName: 'Example',
        processId: 1234,
      );
      expect(app.bundleIdentifier, 'com.example.app');
      expect(app.applicationName, 'Example');
      expect(app.processId, 1234);
    });

    test('equality', () {
      const a = RunningApplication(
        bundleIdentifier: 'com.test',
        applicationName: 'Test',
        processId: 1,
      );
      const b = RunningApplication(
        bundleIdentifier: 'com.test',
        applicationName: 'Test',
        processId: 1,
      );
      expect(a, equals(b));
    });
  });

  group('Window', () {
    test('creates with frame and owning app', () {
      const app = RunningApplication(
        bundleIdentifier: 'com.example',
        applicationName: 'Example',
        processId: 1,
      );
      const window = Window(
        windowId: 100,
        frame: (x: 0, y: 0, width: 800, height: 600),
        owningApplication: app,
        title: 'Test Window',
      );
      expect(window.windowId, 100);
      expect(window.frame.width, 800);
      expect(window.frame.height, 600);
      expect(window.owningApplication.bundleIdentifier, 'com.example');
      expect(window.title, 'Test Window');
    });
  });

  group('getShareableContent', () {
    test(
      'returns ShareableContent on macOS or throws on unsupported',
      () async {
        // On non-macOS: UnsupportedError
        // On macOS: ShareableContent or ScreenCaptureKitException
        // (e.g. permission)
        // Timeout: native call may block on permission dialog or hang
        try {
          final content = await getShareableContent().timeout(
            const Duration(seconds: 5),
            onTimeout: () =>
                throw TimeoutException('getShareableContent timed out'),
          );
          expect(content, isA<ShareableContent>());
          expect(content.displays, isA<List<Display>>());
          expect(content.applications, isA<List<RunningApplication>>());
          expect(content.windows, isA<List<Window>>());
        } on UnsupportedError catch (e) {
          // Expected on non-macOS
          print(e);
        } on ScreenCaptureKitException catch (e) {
          // Expected on macOS without Screen Recording permission
          print(e);
        } on TimeoutException catch (e) {
          // Native call blocked (e.g. permission dialog)
          print(e);
        }
      },
      timeout: Timeout.none,
    );
  });
}
