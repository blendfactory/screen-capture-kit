import 'package:screen_capture_kit/screen_capture_kit.dart';
import 'package:test/test.dart';

void main() {
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
}
