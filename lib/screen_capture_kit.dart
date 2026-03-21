/// Native Dart bindings for macOS ScreenCaptureKit.
///
/// Provides high-performance access to Apple's ScreenCaptureKit API for
/// screen, window, and display capture on macOS 12.3+.
library;

export 'src/application/screen_capture_kit.dart' show ScreenCaptureKit;
export 'src/domain/entities/display.dart';
export 'src/domain/entities/running_application.dart';
export 'src/domain/entities/shareable_content.dart';
export 'src/domain/entities/window.dart';
export 'src/domain/errors/screen_capture_kit_exception.dart';
export 'src/domain/value_objects/capture/capture_resolution.dart';
export 'src/domain/value_objects/capture/capture_stream_delegate_event.dart';
export 'src/domain/value_objects/capture/captured_audio.dart';
export 'src/domain/value_objects/capture/captured_frame.dart';
export 'src/domain/value_objects/capture/captured_image.dart';
export 'src/domain/value_objects/capture/content_filter.dart';
export 'src/domain/value_objects/capture/content_sharing_picker_configuration.dart';
export 'src/domain/value_objects/capture/content_sharing_picker_mode.dart';
export 'src/domain/value_objects/capture/display_refresh_rate.dart';
export 'src/domain/value_objects/capture/frame_rate.dart';
export 'src/domain/value_objects/capture/queue_depth.dart';
export 'src/domain/value_objects/capture/stream_configuration.dart';
export 'src/domain/value_objects/geometry/frame_size.dart';
export 'src/domain/value_objects/geometry/pixel_rect.dart';
export 'src/domain/value_objects/identifiers/bundle_id.dart';
export 'src/domain/value_objects/identifiers/display_id.dart';
export 'src/domain/value_objects/identifiers/filter_id.dart';
export 'src/domain/value_objects/identifiers/process_id.dart';
export 'src/domain/value_objects/identifiers/window_id.dart';
export 'src/presentation/capture_stream.dart';
