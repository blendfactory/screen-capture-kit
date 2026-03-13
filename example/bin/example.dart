import 'dart:async';

import 'package:screen_capture_kit/screen_capture_kit.dart';

void main() async {
  final kit = ScreenCaptureKit();
  try {
    final content = await kit.getShareableContent();
    print('Displays: ${content.displays.length}');
    print('Applications: ${content.applications.length}');
    print('Windows: ${content.windows.length}');

    // Create a window filter and capture a screenshot
    if (content.windows.isNotEmpty) {
      ContentFilterHandle? filterHandle;
      Window? window;
      for (final w in content.windows) {
        try {
          filterHandle = await kit.createWindowFilter(w);
          window = w;
          break;
        } on ScreenCaptureKitException catch (_) {
          continue;
        }
      }
      if (filterHandle == null || window == null) {
        print(
          'No capturable window found. '
          'Try granting Screen Recording permission.',
        );
        return;
      }
      print('\nCreating filter for window: ${window.title ?? window.windowId}');
      print('Filter created: ${filterHandle.filterId}');
      try {
        final image = await kit.captureScreenshot(filterHandle);
        final size = '${image.width}x${image.height}';
        final bytes = image.pngData.length;
        print(
          'Screenshot captured: $size, $bytes bytes PNG',
        );
      } on ScreenCaptureKitException catch (e) {
        if (e.message.contains('macOS 14')) {
          print('Screenshot requires macOS 14+ (current: ${e.message})');
        } else {
          rethrow;
        }
      }

      // Stream capture (blocking FFI runs in isolate)
      print('Starting stream capture...');
      var frameCount = 0;
      final stopwatch = Stopwatch()..start();
      final completer = Completer<void>();
      final w = window.frame.width.toInt();
      final h = window.frame.height.toInt();
      final stream = kit.startCaptureStream(filterHandle, width: w, height: h);
      final subscription = stream.listen(
        (frame) {
          frameCount++;
          if (frameCount <= 3) {
            print('Frame $frameCount: ${frame.width}x${frame.height}');
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
        Future.delayed(
          const Duration(seconds: 5),
          () {
            if (!completer.isCompleted) {
              unawaited(subscription.cancel());
              completer.complete();
            }
          },
        ),
      );
      await completer.future;
      await subscription.cancel();
      final msg = 'Stream captured $frameCount frames in '
          '${stopwatch.elapsedMilliseconds}ms.';
      print(msg);
      kit.releaseFilter(filterHandle);
      print('Filter released.');
    }
  } on UnsupportedError catch (e) {
    print('Unsupported: $e');
  } on ScreenCaptureKitException catch (e) {
    print('ScreenCaptureKit error: $e');
  }
}
