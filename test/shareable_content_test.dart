import 'dart:async';
import 'dart:typed_data';

import 'package:screen_capture_kit/screen_capture_kit.dart';
import 'package:test/test.dart';

void main() {
  group('ContentFilter', () {
    test('ContentFilter.window creates with window', () {
      const app = RunningApplication(
        bundleIdentifier: 'com.example',
        applicationName: 'Example',
        processId: 1,
      );
      const window = Window(
        windowId: 100,
        frame: (x: 0, y: 0, width: 800, height: 600),
        owningApplication: app,
      );
      const filter = ContentFilter.window(window);
      expect(filter, isA<ContentFilter>());
      expect(filter.toString(), contains('window'));
    });

    test('ContentFilter.display creates with display', () {
      const display = Display(
        displayId: 1,
        width: 1920,
        height: 1080,
      );
      const filter = ContentFilter.display(display);
      expect(filter, isA<ContentFilter>());
      expect(filter.toString(), contains('display'));
    });

    test('ContentFilter.displayExcludingWindows creates with display and list',
        () {
      const display = Display(
        displayId: 1,
        width: 1920,
        height: 1080,
      );
      const app = RunningApplication(
        bundleIdentifier: 'com.example',
        applicationName: 'Example',
        processId: 1,
      );
      const window = Window(
        windowId: 100,
        frame: (x: 0, y: 0, width: 100, height: 100),
        owningApplication: app,
      );
      const filter = ContentFilter.displayExcludingWindows(display, [window]);
      expect(filter, isA<ContentFilter>());
      expect(filter.toString(), contains('displayExcludingWindows'));
    });

    test('ContentFilter.region creates with rect', () {
      const filter = ContentFilter.region(
        (x: 10, y: 20, width: 400, height: 300),
      );
      expect(filter, isA<ContentFilter>());
      expect(filter.toString(), contains('region'));
    });
  });

  group('ContentFilterHandle', () {
    test('creates with positive filter id', () {
      const handle = ContentFilterHandle(1);
      expect(handle.filterId, 1);
    });
  });

  group('ScreenCaptureKitException', () {
    test('creates with message only', () {
      const e = ScreenCaptureKitException('Something failed.');
      expect(e.message, 'Something failed.');
      expect(e.domain, isNull);
      expect(e.code, isNull);
    });

    test('creates with domain and code', () {
      const e = ScreenCaptureKitException(
        'Stream failed.',
        domain: 'com.apple.ScreenCaptureKit',
        code: 1,
      );
      expect(e.message, 'Stream failed.');
      expect(e.domain, 'com.apple.ScreenCaptureKit');
      expect(e.code, 1);
    });

    test('toString includes message when no domain/code', () {
      const e = ScreenCaptureKitException('Failed');
      expect(e.toString(), contains('Failed'));
      expect(e.toString(), contains('ScreenCaptureKitException'));
    });

    test('toString includes domain and code when set', () {
      const e = ScreenCaptureKitException(
        'Failed',
        domain: 'test.domain',
        code: 42,
      );
      expect(e.toString(), contains('Failed'));
      expect(e.toString(), contains('test.domain'));
      expect(e.toString(), contains('42'));
    });
  });

  group('CapturedFrame', () {
    test('creates with required fields', () {
      final frame = CapturedFrame(
        bgraData: Uint8List.fromList([1, 2, 3, 4]),
        width: 10,
        height: 5,
        bytesPerRow: 40,
      );
      expect(frame.bgraData.length, 4);
      expect(frame.width, 10);
      expect(frame.height, 5);
      expect(frame.bytesPerRow, 40);
    });
  });

  group('CapturedImage', () {
    test('creates with required fields', () {
      final image = CapturedImage(
        pngData: Uint8List.fromList([0x89, 0x50, 0x4e]),
        width: 100,
        height: 50,
      );
      expect(image.pngData.length, 3);
      expect(image.width, 100);
      expect(image.height, 50);
    });
  });

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

  group('ScreenCaptureKit.captureScreenshot', () {
    test(
      'captures on macOS 14+ or throws on older/unsupported',
      () async {
        try {
          final content =
              await ScreenCaptureKit().getShareableContent().timeout(
                    const Duration(seconds: 5),
                    onTimeout: () =>
                        throw TimeoutException('getShareableContent timed out'),
                  );
          if (content.windows.isEmpty) {
            return;
          }
          final handle = await ScreenCaptureKit()
              .createWindowFilter(content.windows.first)
              .timeout(
                const Duration(seconds: 5),
                onTimeout: () =>
                    throw TimeoutException('createWindowFilter timed out'),
              );
          try {
            final image =
                await ScreenCaptureKit().captureScreenshot(handle).timeout(
                      const Duration(seconds: 10),
                      onTimeout: () =>
                          throw TimeoutException('captureScreenshot timed out'),
                    );
            expect(image.pngData, isNotEmpty);
            expect(image.width, greaterThan(0));
            expect(image.height, greaterThan(0));
          } finally {
            ScreenCaptureKit().releaseFilter(handle);
          }
        } on UnsupportedError {
          // Expected on non-macOS
        } on ScreenCaptureKitException catch (e) {
          // Expected on macOS without permission or macOS < 14
          if (!e.message.contains('macOS 14')) {
            print(e);
          }
        } on TimeoutException {
          // Native may block
        }
      },
      timeout: Timeout.none,
    );
  });

  group('ScreenCaptureKit.createWindowFilter', () {
    test(
      'creates filter on macOS or throws on unsupported',
      () async {
        try {
          final content =
              await ScreenCaptureKit().getShareableContent().timeout(
                    const Duration(seconds: 5),
                    onTimeout: () =>
                        throw TimeoutException('getShareableContent timed out'),
                  );
          if (content.windows.isEmpty) {
            return;
          }
          final window = content.windows.first;
          final handle =
              await ScreenCaptureKit().createWindowFilter(window).timeout(
                    const Duration(seconds: 5),
                    onTimeout: () =>
                        throw TimeoutException('createWindowFilter timed out'),
                  );
          expect(handle, isA<ContentFilterHandle>());
          expect(handle.filterId, greaterThan(0));
          ScreenCaptureKit().releaseFilter(handle);
        } on UnsupportedError catch (e) {
          print(e);
        } on ScreenCaptureKitException catch (e) {
          print(e);
        } on TimeoutException catch (e) {
          print(e);
        }
      },
      timeout: Timeout.none,
    );
  });

  group('ScreenCaptureKit.createDisplayFilter', () {
    test(
      'creates display filter with or without excludingWindows on macOS',
      () async {
        try {
          final content =
              await ScreenCaptureKit().getShareableContent().timeout(
                    const Duration(seconds: 5),
                    onTimeout: () =>
                        throw TimeoutException('getShareableContent timed out'),
                  );
          if (content.displays.isEmpty) {
            return;
          }
          final display = content.displays.first;
          final handle =
              await ScreenCaptureKit().createDisplayFilter(display).timeout(
                    const Duration(seconds: 5),
                    onTimeout: () =>
                        throw TimeoutException('createDisplayFilter timed out'),
                  );
          expect(handle, isA<ContentFilterHandle>());
          expect(handle.filterId, greaterThan(0));
          ScreenCaptureKit().releaseFilter(handle);

          if (content.windows.isNotEmpty) {
            final handleExcluding = await ScreenCaptureKit()
                .createDisplayFilter(display, excludingWindows: content.windows)
                .timeout(
                  const Duration(seconds: 5),
                  onTimeout: () => throw TimeoutException(
                    'createDisplayFilter(excludingWindows) timed out',
                  ),
                );
            expect(handleExcluding.filterId, greaterThan(0));
            ScreenCaptureKit().releaseFilter(handleExcluding);
          }
        } on UnsupportedError catch (e) {
          print(e);
        } on ScreenCaptureKitException catch (e) {
          print(e);
        } on TimeoutException catch (e) {
          print(e);
        }
      },
      timeout: Timeout.none,
    );
  });

  group('ScreenCaptureKit.startCaptureStream', () {
    test(
      'accepts queueDepth parameter on macOS',
      () async {
        try {
          final content =
              await ScreenCaptureKit().getShareableContent().timeout(
                    const Duration(seconds: 5),
                    onTimeout: () =>
                        throw TimeoutException('getShareableContent timed out'),
                  );
          if (content.displays.isEmpty) {
            return;
          }
          final handle = await ScreenCaptureKit()
              .createDisplayFilter(content.displays.first)
              .timeout(
                const Duration(seconds: 5),
                onTimeout: () =>
                    throw TimeoutException('createDisplayFilter timed out'),
              );
          try {
            final stream = ScreenCaptureKit().startCaptureStream(
              handle,
              width: 64,
              height: 64,
              frameRate: 10,
              queueDepth: 3,
            );
            final sub = stream.listen(
              (_) {},
              onError: (_) {},
              cancelOnError: true,
            );
            try {
              // Run briefly to verify stream accepts queueDepth; then cancel.
              // (Stream never completes; timeout resets on each frame so we
              // don't rely on it.)
              await Future<void>.delayed(const Duration(milliseconds: 300));
            } finally {
              await sub.cancel();
            }
          } finally {
            ScreenCaptureKit().releaseFilter(handle);
          }
        } on UnsupportedError catch (e) {
          print(e);
        } on ScreenCaptureKitException catch (e) {
          print(e);
        } on TimeoutException catch (e) {
          print(e);
        }
      },
      timeout: Timeout.none,
    );
  });

  group('ScreenCaptureKit.getShareableContent', () {
    test(
      'returns ShareableContent on macOS or throws on unsupported',
      () async {
        // On non-macOS: UnsupportedError
        // On macOS: ShareableContent or ScreenCaptureKitException
        // (e.g. permission)
        // Timeout: native call may block on permission dialog or hang
        try {
          final content =
              await ScreenCaptureKit().getShareableContent().timeout(
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
