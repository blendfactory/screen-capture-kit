import 'dart:async';

import 'package:screen_capture_kit/screen_capture_kit.dart';
import 'package:test/test.dart';

void main() {
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
}
