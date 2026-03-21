import 'package:screen_capture_kit/screen_capture_kit.dart';
import 'package:test/test.dart';

void main() {
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
}
