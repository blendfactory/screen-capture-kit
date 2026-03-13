import 'package:screen_capture_kit/screen_capture_kit.dart';

void main() async {
  try {
    final content = await getShareableContent();
    print('Displays: ${content.displays.length}');
    print('Applications: ${content.applications.length}');
    print('Windows: ${content.windows.length}');
  } on UnsupportedError catch (e) {
    print('Unsupported: $e');
  } on UnimplementedError catch (e) {
    print('Not yet implemented: $e');
  }
}
