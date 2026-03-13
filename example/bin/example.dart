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
      final window = content.windows.first;
      print('\nCreating filter for window: ${window.title ?? window.windowId}');
      final filterHandle = await kit.createWindowFilter(window);
      print('Filter created: ${filterHandle.filterId}');
      try {
        final image = await kit.captureScreenshot(filterHandle);
        print('Screenshot captured: ${image.width}x${image.height}, '
            '${image.pngData.length} bytes PNG');
      } on ScreenCaptureKitException catch (e) {
        if (e.message.contains('macOS 14')) {
          print('Screenshot requires macOS 14+ (current: ${e.message})');
        } else {
          rethrow;
        }
      }

      // Stream capture (experimental - may crash;
      // use captureScreenshot for now)
      // await for (final frame in kit.startCaptureStream(filterHandle)) {
      //   ...
      // }
      kit.releaseFilter(filterHandle);
      print('Filter released.');
    }
  } on UnsupportedError catch (e) {
    print('Unsupported: $e');
  } on ScreenCaptureKitException catch (e) {
    print('ScreenCaptureKit error: $e');
  }
}
