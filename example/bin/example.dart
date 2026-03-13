import 'package:screen_capture_kit/screen_capture_kit.dart';

void main() async {
  final kit = ScreenCaptureKit();
  try {
    final content = await kit.getShareableContent();
    print('Displays: ${content.displays.length}');
    print('Applications: ${content.applications.length}');
    print('Windows: ${content.windows.length}');
  } on UnsupportedError catch (e) {
    print('Unsupported: $e');
  } on ScreenCaptureKitException catch (e) {
    print('ScreenCaptureKit error: $e');
  }
}
