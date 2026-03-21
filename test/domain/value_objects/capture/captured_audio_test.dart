import 'dart:typed_data';

import 'package:screen_capture_kit/screen_capture_kit.dart';
import 'package:test/test.dart';

void main() {
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
}
