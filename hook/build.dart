import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) {
      return;
    }

    switch (input.config.code.targetOS) {
      case OS.macOS:
        final packageName = input.packageName;
        final cbuilder = CBuilder.library(
          name: packageName,
          packageName: packageName,
          assetName: '$packageName.dart',
          sources: [
            'native/shareable_content.m',
            'native/content_filter.m',
            'native/screenshot.m',
            'native/stream.m',
          ],
          frameworks: [
            'ScreenCaptureKit',
            'Foundation',
            'CoreGraphics',
            'ImageIO',
            'CoreMedia',
            'CoreVideo',
            'IOSurface',
          ],
          language: Language.objectiveC,
          flags: ['-mmacosx-version-min=12.3'],
        );
        await cbuilder.run(input: input, output: output);
      default:
        break;
    }
  });
}
