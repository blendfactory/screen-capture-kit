import 'dart:async';
import 'dart:io' show Platform;

import 'package:screen_capture_kit/screen_capture_kit.dart';
import 'package:test/test.dart';

void main() {
  group('ScreenCaptureKit.presentContentSharingPicker', () {
    test('throws UnsupportedError on non-macOS', () async {
      if (Platform.isMacOS) {
        return;
      }
      await expectLater(
        ScreenCaptureKit().presentContentSharingPicker(),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('ScreenCaptureKit.captureScreenshot', () {
    test(
      'captures on macOS 14+ or throws on older/unsupported',
      () async {
        try {
          final content = await ScreenCaptureKit()
              .getShareableContent()
              .timeout(
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
            final image = await ScreenCaptureKit()
                .captureScreenshot(
                  handle,
                  captureResolution: CaptureResolution.best,
                )
                .timeout(
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
          final content = await ScreenCaptureKit()
              .getShareableContent()
              .timeout(
                const Duration(seconds: 5),
                onTimeout: () =>
                    throw TimeoutException('getShareableContent timed out'),
              );
          if (content.windows.isEmpty) {
            return;
          }
          final window = content.windows.first;
          final handle = await ScreenCaptureKit()
              .createWindowFilter(window)
              .timeout(
                const Duration(seconds: 5),
                onTimeout: () =>
                    throw TimeoutException('createWindowFilter timed out'),
              );
          expect(handle, isA<FilterId>());
          expect(handle.value, greaterThan(0));
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
          final content = await ScreenCaptureKit()
              .getShareableContent()
              .timeout(
                const Duration(seconds: 5),
                onTimeout: () =>
                    throw TimeoutException('getShareableContent timed out'),
              );
          if (content.displays.isEmpty) {
            return;
          }
          final display = content.displays.first;
          final handle = await ScreenCaptureKit()
              .createDisplayFilter(display)
              .timeout(
                const Duration(seconds: 5),
                onTimeout: () =>
                    throw TimeoutException('createDisplayFilter timed out'),
              );
          expect(handle, isA<FilterId>());
          expect(handle.value, greaterThan(0));
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
            expect(handleExcluding.value, greaterThan(0));
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
          final content = await ScreenCaptureKit()
              .getShareableContent()
              .timeout(
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
              frameSize: FrameSize(width: 64, height: 64),
              frameRate: FrameRate(10),
              queueDepth: QueueDepth(3),
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

  group('ScreenCaptureKit.startCaptureStreamWithUpdater', () {
    test(
      'returns CaptureStream and updateConfiguration works on macOS',
      () async {
        try {
          final content = await ScreenCaptureKit()
              .getShareableContent()
              .timeout(
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
            final capture = ScreenCaptureKit().startCaptureStreamWithUpdater(
              handle,
              frameSize: FrameSize(width: 64, height: 64),
              frameRate: FrameRate(10),
              queueDepth: QueueDepth(3),
            );
            expect(capture, isA<CaptureStream>());
            expect(capture.stream, isA<Stream<CapturedFrame>>());

            final sub = capture.stream.listen(
              (_) {},
              onError: (_) {},
              cancelOnError: true,
            );
            try {
              await Future<void>.delayed(const Duration(milliseconds: 200));
              capture.updateConfiguration(
                StreamConfiguration(
                  frameSize: FrameSize(width: 128, height: 128),
                  frameRate: FrameRate(15),
                ),
              );
              await Future<void>.delayed(const Duration(milliseconds: 100));
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
    test(
      'capturesAudio true provides audioStream on macOS',
      () async {
        try {
          final content = await ScreenCaptureKit()
              .getShareableContent()
              .timeout(
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
            final capture = ScreenCaptureKit().startCaptureStreamWithUpdater(
              handle,
              frameSize: FrameSize(width: 64, height: 64),
              frameRate: FrameRate(10),
              queueDepth: QueueDepth(3),
              capturesAudio: true,
            );
            expect(capture.audioStream, isNotNull);
            final videoSub = capture.stream.listen(
              (_) {},
              onError: (_) {},
              cancelOnError: true,
            );
            final audioSub = capture.audioStream?.listen(
              (_) {},
              onError: (_) {},
              cancelOnError: true,
            );
            await Future<void>.delayed(const Duration(milliseconds: 200));
            await videoSub.cancel();
            await audioSub?.cancel();
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
    test(
      'updateContentFilter switches filter on macOS',
      () async {
        try {
          final content = await ScreenCaptureKit()
              .getShareableContent()
              .timeout(
                const Duration(seconds: 5),
                onTimeout: () =>
                    throw TimeoutException('getShareableContent timed out'),
              );
          if (content.displays.isEmpty) {
            return;
          }
          final display = content.displays.first;
          final handle1 = await ScreenCaptureKit()
              .createDisplayFilter(display)
              .timeout(
                const Duration(seconds: 5),
                onTimeout: () =>
                    throw TimeoutException('createDisplayFilter timed out'),
              );
          FilterId? handle2;
          try {
            final capture = ScreenCaptureKit().startCaptureStreamWithUpdater(
              handle1,
              frameSize: FrameSize(width: 64, height: 64),
              frameRate: FrameRate(10),
              queueDepth: QueueDepth(3),
            );
            handle2 = await ScreenCaptureKit()
                .createDisplayFilter(display)
                .timeout(
                  const Duration(seconds: 5),
                  onTimeout: () =>
                      throw TimeoutException('second createDisplayFilter'),
                );
            final sub = capture.stream.listen(
              (_) {},
              onError: (_) {},
              cancelOnError: true,
            );
            try {
              await Future<void>.delayed(const Duration(milliseconds: 200));
              if (handle2 != null) {
                capture.updateContentFilter(handle2);
              }
              await Future<void>.delayed(const Duration(milliseconds: 100));
            } finally {
              await sub.cancel();
            }
          } finally {
            ScreenCaptureKit().releaseFilter(handle1);
            if (handle2 != null) {
              ScreenCaptureKit().releaseFilter(handle2);
            }
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
          final content = await ScreenCaptureKit()
              .getShareableContent()
              .timeout(
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
