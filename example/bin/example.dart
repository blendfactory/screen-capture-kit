import 'dart:async';

import 'package:screen_capture_kit/screen_capture_kit.dart';

/// Runs stream capture for the given filter and returns frame count.
Future<int> runStreamCapture(
  ScreenCaptureKit kit,
  FilterId filterHandle, {
  required int width,
  required int height,
  required String label,
  PixelRect? sourceRect,
  Duration timeout = const Duration(seconds: 5),
}) async {
  print('\n--- $label ---');
  var frameCount = 0;
  final stopwatch = Stopwatch()..start();
  final completer = Completer<void>();
  final stream = kit.startCaptureStream(
    filterHandle,
    frameSize: FrameSize(width: width, height: height),
    sourceRect: sourceRect,
  );
  final subscription = stream.listen(
    (frame) {
      frameCount++;
      if (frameCount <= 3) {
        print('Frame $frameCount: ${frame.size.width}x${frame.size.height}');
      }
      if (frameCount >= 10 && !completer.isCompleted) {
        completer.complete();
      }
    },
    onError: (Object e, StackTrace st) {
      print('Stream error: $e');
      if (!completer.isCompleted) {
        completer.complete();
      }
    },
    onDone: () {
      if (!completer.isCompleted) {
        completer.complete();
      }
    },
  );
  unawaited(
    Future.delayed(timeout, () {
      if (!completer.isCompleted) {
        unawaited(subscription.cancel());
        completer.complete();
      }
    }),
  );
  await completer.future;
  await subscription.cancel();
  print('$label: $frameCount frames in ${stopwatch.elapsedMilliseconds}ms');
  return frameCount;
}

void main() async {
  final kit = ScreenCaptureKit();
  try {
    final content = await kit.getShareableContent();
    print('Displays: ${content.displays.length}');
    print('Applications: ${content.applications.length}');
    print('Windows: ${content.windows.length}');

    // 1. Display filter: capture entire display
    if (content.displays.isNotEmpty) {
      final display = content.displays.first;
      print(
        '\n=== Display capture (displayId: ${display.displayId.value}) ===',
      );
      final displayFilter = await kit.createDisplayFilter(display);
      print('Display filter created: ${displayFilter.filterId}');
      try {
        final image = await kit.captureScreenshot(displayFilter);
        print(
          'Screenshot: ${image.width}x${image.height}, '
          '${image.pngData.length} bytes',
        );
      } on ScreenCaptureKitException catch (e) {
        if (e.message.contains('macOS 14')) {
          print('Screenshot requires macOS 14+');
        } else {
          rethrow;
        }
      }
      await runStreamCapture(
        kit,
        displayFilter,
        width: display.width,
        height: display.height,
        label: 'Display stream',
      );

      // Region capture: center 400x400 via sourceRect (reuses display filter)
      const regionW = 400.0;
      const regionH = 400.0;
      final regionX = (display.width - regionW) / 2;
      final regionY = (display.height - regionH) / 2;
      print(
        '\n=== Region capture (center '
        '${regionW.toInt()}x${regionH.toInt()}) ===',
      );
      await runStreamCapture(
        kit,
        displayFilter,
        width: regionW.toInt(),
        height: regionH.toInt(),
        sourceRect: PixelRect(
          x: regionX,
          y: regionY,
          width: regionW,
          height: regionH,
        ),
        label: 'Region stream',
      );

      kit.releaseFilter(displayFilter);
      print('Display filter released.');
    }

    // 2. Window filter: capture single window
    if (content.windows.isNotEmpty) {
      FilterId? windowFilter;
      Window? window;
      for (final w in content.windows) {
        try {
          windowFilter = await kit.createWindowFilter(w);
          window = w;
          break;
        } on ScreenCaptureKitException catch (_) {
          continue;
        }
      }
      if (windowFilter != null && window != null) {
        print(
          '\n=== Window capture (${window.title ?? window.windowId.value}) ===',
        );
        print('Window filter created: ${windowFilter.filterId}');
        try {
          final image = await kit.captureScreenshot(windowFilter);
          print(
            'Screenshot: ${image.width}x${image.height}, '
            '${image.pngData.length} bytes',
          );
        } on ScreenCaptureKitException catch (e) {
          if (e.message.contains('macOS 14')) {
            print('Screenshot requires macOS 14+');
          } else {
            rethrow;
          }
        }
        // Window stream skipped - display stream is stable
        kit.releaseFilter(windowFilter);
        print('Window filter released.');
      } else {
        print('\nNo capturable window found.');
      }
    }

    // 3. System picker (macOS 14+): user selects content from system UI
    try {
      print('\n=== System content-sharing picker (macOS 14+) ===');
      final pickerFilter = await kit.presentContentSharingPicker(
        allowedModes: [
          ContentSharingPickerMode.singleDisplay,
          ContentSharingPickerMode.singleWindow,
        ],
      );
      if (pickerFilter != null) {
        try {
          await runStreamCapture(
            kit,
            pickerFilter,
            width: 640,
            height: 480,
            label: 'Picker stream',
          );
        } finally {
          kit.releaseFilter(pickerFilter);
        }
        print('Picker filter released.');
      } else {
        print('Picker cancelled or unavailable.');
      }
    } on ScreenCaptureKitException catch (e) {
      if (e.message.contains('macOS 14')) {
        print('System picker requires macOS 14+');
      } else {
        rethrow;
      }
    }
  } on UnsupportedError catch (e) {
    print('Unsupported: $e');
  } on ScreenCaptureKitException catch (e) {
    print('ScreenCaptureKit error: $e');
  }
}
