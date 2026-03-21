import 'package:screen_capture_kit/screen_capture_kit.dart';
import 'package:test/test.dart';

void main() {
  group('StreamConfiguration', () {
    test('creates with defaults', () {
      const config = StreamConfiguration();
      expect(config.frameSize, const FrameSize.zero());
      expect(config.frameSize.width, 0);
      expect(config.frameSize.height, 0);
      expect(config.frameRate, const FrameRate.fps60());
      expect(config.sourceRect, isNull);
      expect(config.scalesToFit, isNull);
      expect(config.destinationRect, isNull);
      expect(config.preservesAspectRatio, isNull);
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
        sourceRect: PixelRect(x: 0, y: 0, width: 320, height: 240),
        scalesToFit: false,
        destinationRect: PixelRect(
          x: 0,
          y: 0,
          width: 320,
          height: 240,
        ),
        preservesAspectRatio: false,
        showsCursor: false,
        queueDepth: QueueDepth(8),
      );
      expect(config.frameSize.width, 320);
      expect(config.frameSize.height, 240);
      expect(config.frameRate.value, 30);
      expect(config.sourceRect?.width, 320);
      expect(config.scalesToFit, isFalse);
      expect(config.destinationRect?.width, 320);
      expect(config.preservesAspectRatio, isFalse);
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
}
