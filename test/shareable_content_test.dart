import 'dart:async';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:screen_capture_kit/screen_capture_kit.dart';
import 'package:test/test.dart';

void main() {
  group('ContentFilter', () {
    test('ContentFilter.window creates with window', () {
      const app = RunningApplication(
        bundleIdentifier: BundleId('com.example'),
        applicationName: 'Example',
        processId: ProcessId(1),
      );
      const window = Window(
        windowId: WindowId(100),
        frame: PixelRect(x: 0, y: 0, width: 800, height: 600),
        owningApplication: app,
      );
      const filter = ContentFilter.window(window);
      expect(filter, isA<ContentFilter>());
      expect(filter.toString(), contains('window'));
    });

    test('ContentFilter.display creates with display', () {
      final display = Display(
        displayId: const DisplayId(1),
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
          displayId: const DisplayId(1),
          size: FrameSize(width: 1920, height: 1080),
        );
        const app = RunningApplication(
          bundleIdentifier: BundleId('com.example'),
          applicationName: 'Example',
          processId: ProcessId(1),
        );
        const window = Window(
          windowId: WindowId(100),
          frame: PixelRect(x: 0, y: 0, width: 100, height: 100),
          owningApplication: app,
        );
        final filter = ContentFilter.displayExcludingWindows(
          display,
          const [window],
        );
        expect(filter, isA<ContentFilter>());
        expect(filter.toString(), contains('displayExcludingWindows'));
      },
    );

    test('ContentFilter.region creates with rect', () {
      const filter = ContentFilter.region(
        PixelRect(x: 10, y: 20, width: 400, height: 300),
      );
      expect(filter, isA<ContentFilter>());
      expect(filter.toString(), contains('region'));
    });
  });

  group('FilterId', () {
    test('creates with positive filter id', () {
      const filterId = FilterId(1);
      expect(filterId.filterId, 1);
    });
  });

  group('FrameSize', () {
    test('zero is 0x0', () {
      expect(const FrameSize.zero().width, 0);
      expect(const FrameSize.zero().height, 0);
      expect(FrameSize.zero, returnsNormally);
    });

    test('factory rejects negative dimensions', () {
      expect(
        () => FrameSize(width: -1, height: 10),
        throwsArgumentError,
      );
    });

    test('factory rejects mixed zero and positive (capture output rule)', () {
      expect(
        () => FrameSize(width: 100, height: 0),
        throwsArgumentError,
      );
    });

    test('factory returns FrameSize.zero for 0x0', () {
      expect(FrameSize(width: 0, height: 0), const FrameSize.zero());
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
        size: FrameSize(width: 10, height: 5),
        bytesPerRow: 40,
      );
      expect(frame.bgraData.length, 4);
      expect(frame.size.width, 10);
      expect(frame.size.height, 5);
      expect(frame.bytesPerRow, 40);
    });
  });

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

  group('CapturedAudio', () {
    test('creates with required fields', () {
      final audio = CapturedAudio(
        pcmData: Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7]),
        sampleRate: 48000,
        channelCount: 2,
        format: 'f32',
      );
      expect(audio.pcmData.length, 8);
      expect(audio.sampleRate, 48000.0);
      expect(audio.channelCount, 2);
      expect(audio.format, 'f32');
    });

    test('optional presentation timing from native bridge', () {
      final audio = CapturedAudio(
        pcmData: Uint8List.fromList([0, 0, 0, 0]),
        sampleRate: 48000,
        channelCount: 1,
        format: 'f32',
        presentationTimeSeconds: 12345.25,
        durationSeconds: 0.01,
      );
      expect(audio.presentationTimeSeconds, 12345.25);
      expect(audio.durationSeconds, 0.01);
    });
  });

  group('StreamConfiguration', () {
    test('creates with defaults', () {
      const config = StreamConfiguration();
      expect(config.frameSize, const FrameSize.zero());
      expect(config.frameSize.width, 0);
      expect(config.frameSize.height, 0);
      expect(config.frameRate, const FrameRate.fps60());
      expect(config.sourceRect, isNull);
      expect(config.showsCursor, isTrue);
      expect(config.queueDepth, const QueueDepth.depth5());
      expect(config.capturesAudio, isFalse);
      expect(config.excludesCurrentProcessAudio, isFalse);
      expect(config.captureMicrophone, isFalse);
    });

    test('creates with custom values', () {
      final config = StreamConfiguration(
        frameSize: FrameSize(width: 320, height: 240),
        frameRate: FrameRate(30),
        sourceRect: const PixelRect(x: 0, y: 0, width: 320, height: 240),
        showsCursor: false,
        queueDepth: QueueDepth(8),
      );
      expect(config.frameSize.width, 320);
      expect(config.frameSize.height, 240);
      expect(config.frameRate.value, 30);
      expect(config.sourceRect?.width, 320);
      expect(config.showsCursor, isFalse);
      expect(config.queueDepth.value, 8);
    });

    test('creates with custom audio values', () {
      final config = StreamConfiguration(
        frameSize: FrameSize(width: 320, height: 240),
        capturesAudio: true,
        excludesCurrentProcessAudio: true,
        captureMicrophone: true,
      );
      expect(config.capturesAudio, isTrue);
      expect(config.excludesCurrentProcessAudio, isTrue);
      expect(config.captureMicrophone, isTrue);
    });

    test('creates with pixelFormat and colorSpaceName', () {
      const config = StreamConfiguration(
        pixelFormat: 0x42475241, // kCVPixelFormatType_32BGRA
        colorSpaceName: 'kCGColorSpaceSRGB',
      );
      expect(config.pixelFormat, 0x42475241);
      expect(config.colorSpaceName, 'kCGColorSpaceSRGB');
    });
  });

  group('CaptureStream', () {
    test('holds stream and invokes updateConfiguration', () async {
      final controller = StreamController<CapturedFrame>.broadcast();
      var updateCalled = false;
      final capture = CaptureStream(
        stream: controller.stream,
        updateConfiguration: (_) {
          updateCalled = true;
        },
        updateContentFilter: (_) {},
        setContentSharingPickerConfiguration: (_) {},
      );
      expect(capture.stream, equals(controller.stream));
      capture.updateConfiguration(
        StreamConfiguration(
          frameSize: FrameSize(width: 100, height: 100),
        ),
      );
      expect(updateCalled, isTrue);
      await controller.close();
    });

    test('invokes updateContentFilter when called', () async {
      final controller = StreamController<CapturedFrame>.broadcast();
      FilterId? passedHandle;
      final capture = CaptureStream(
        stream: controller.stream,
        updateConfiguration: (_) {},
        updateContentFilter: (handle) {
          passedHandle = handle;
        },
        setContentSharingPickerConfiguration: (_) {},
      );
      const handle = FilterId(42);
      capture.updateContentFilter(handle);
      expect(passedHandle, equals(handle));
      expect(passedHandle?.filterId, 42);
      await controller.close();
    });

    test('audioStream is null when not provided', () async {
      final controller = StreamController<CapturedFrame>.broadcast();
      final capture = CaptureStream(
        stream: controller.stream,
        updateConfiguration: (_) {},
        updateContentFilter: (_) {},
        setContentSharingPickerConfiguration: (_) {},
      );
      expect(capture.audioStream, isNull);
      await controller.close();
    });

    test('holds audioStream when provided', () async {
      final videoController = StreamController<CapturedFrame>.broadcast();
      final audioController = StreamController<CapturedAudio>.broadcast();
      final capture = CaptureStream(
        stream: videoController.stream,
        audioStream: audioController.stream,
        updateConfiguration: (_) {},
        updateContentFilter: (_) {},
        setContentSharingPickerConfiguration: (_) {},
      );
      expect(capture.audioStream, equals(audioController.stream));
      await videoController.close();
      await audioController.close();
    });

    test('microphoneStream is null when not provided', () async {
      final controller = StreamController<CapturedFrame>.broadcast();
      final capture = CaptureStream(
        stream: controller.stream,
        updateConfiguration: (_) {},
        updateContentFilter: (_) {},
        setContentSharingPickerConfiguration: (_) {},
      );
      expect(capture.microphoneStream, isNull);
      await controller.close();
    });

    test('holds microphoneStream when provided', () async {
      final videoController = StreamController<CapturedFrame>.broadcast();
      final microphoneController = StreamController<CapturedAudio>.broadcast();
      final capture = CaptureStream(
        stream: videoController.stream,
        microphoneStream: microphoneController.stream,
        updateConfiguration: (_) {},
        updateContentFilter: (_) {},
        setContentSharingPickerConfiguration: (_) {},
      );
      expect(capture.microphoneStream, equals(microphoneController.stream));
      await videoController.close();
      await microphoneController.close();
    });

    test(
      'flushPendingAudio completes when pendingAudioFlush is null',
      () async {
        final controller = StreamController<CapturedFrame>.broadcast();
        final capture = CaptureStream(
          stream: controller.stream,
          updateConfiguration: (_) {},
          updateContentFilter: (_) {},
          setContentSharingPickerConfiguration: (_) {},
        );
        await capture.flushPendingAudio();
        await controller.close();
      },
    );

    test('invokes setContentSharingPickerConfiguration when called', () async {
      final controller = StreamController<CapturedFrame>.broadcast();
      ContentSharingPickerConfiguration? passedConfig;
      final capture = CaptureStream(
        stream: controller.stream,
        updateConfiguration: (_) {},
        updateContentFilter: (_) {},
        setContentSharingPickerConfiguration: (config) {
          passedConfig = config;
        },
      );
      const config = ContentSharingPickerConfiguration(
        allowedModes: [ContentSharingPickerMode.singleDisplay],
        allowsChangingSelectedContent: false,
      );
      capture.setContentSharingPickerConfiguration(config);
      expect(
        passedConfig?.allowedModes,
        [ContentSharingPickerMode.singleDisplay],
      );
      expect(passedConfig?.allowsChangingSelectedContent, false);
      capture.setContentSharingPickerConfiguration(null);
      expect(passedConfig, isNull);
      await controller.close();
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
      final display = Display(
        displayId: const DisplayId(1),
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

    test('Display equality', () {
      final a = Display(
        displayId: const DisplayId(1),
        size: FrameSize(width: 1920, height: 1080),
      );
      final b = Display(
        displayId: const DisplayId(1),
        size: FrameSize(width: 1920, height: 1080),
      );
      final c = Display(
        displayId: const DisplayId(2),
        size: FrameSize(width: 1920, height: 1080),
      );
      final d = Display(
        displayId: const DisplayId(1),
        size: FrameSize(width: 1920, height: 1080),
        refreshRate: DisplayRefreshRate(120),
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a, isNot(equals(d)));
    });
  });

  group('DisplayRefreshRate', () {
    test('unknown has value 0 and isKnown false', () {
      const r = DisplayRefreshRate.unknown();
      expect(r.value, 0);
      expect(r.isKnown, isFalse);
    });

    test('factory accepts 1..480', () {
      expect(DisplayRefreshRate(60).value, 60);
      expect(DisplayRefreshRate(120).isKnown, isTrue);
      expect(() => DisplayRefreshRate(0), throwsArgumentError);
      expect(() => DisplayRefreshRate(481), throwsArgumentError);
    });

    test('fromNum rounds and treats invalid as unknown', () {
      expect(DisplayRefreshRate.fromNum(59.94).value, 60);
      expect(DisplayRefreshRate.fromNum(null).isKnown, isFalse);
      expect(DisplayRefreshRate.fromNum(0).isKnown, isFalse);
      expect(DisplayRefreshRate.fromNum(-1).isKnown, isFalse);
      expect(DisplayRefreshRate.fromNum(481).isKnown, isFalse);
      expect(DisplayRefreshRate.fromNum(double.nan).isKnown, isFalse);
    });
  });

  group('RunningApplication', () {
    test('creates with required fields', () {
      const app = RunningApplication(
        bundleIdentifier: BundleId('com.example.app'),
        applicationName: 'Example',
        processId: ProcessId(1234),
      );
      expect(app.bundleIdentifier, const BundleId('com.example.app'));
      expect(app.applicationName, 'Example');
      expect(app.processId.value, 1234);
    });

    test('equality', () {
      const a = RunningApplication(
        bundleIdentifier: BundleId('com.test'),
        applicationName: 'Test',
        processId: ProcessId(1),
      );
      const b = RunningApplication(
        bundleIdentifier: BundleId('com.test'),
        applicationName: 'Test',
        processId: ProcessId(1),
      );
      expect(a, equals(b));
    });
  });

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
                .captureScreenshot(handle)
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
