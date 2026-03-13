#import "content_filter.h"
#import <ScreenCaptureKit/ScreenCaptureKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#include <string.h>

#if __MAC_OS_X_VERSION_MIN_REQUIRED < 120300
#error "ScreenCaptureKit requires macOS 12.3 or newer"
#endif

static void ensureCoreGraphicsInit(void) {
  (void)CGMainDisplayID();
}

@interface StreamFrameHandler : NSObject <SCStreamOutput>
@property (nonatomic, strong) NSMutableData* latestFrame;
@property (nonatomic, assign) int frameWidth;
@property (nonatomic, assign) int frameHeight;
@property (nonatomic, assign) int bytesPerRow;
@property (nonatomic, strong) dispatch_semaphore_t frameSemaphore;
@property (nonatomic, assign) BOOL stopped;
@end

@implementation StreamFrameHandler
- (instancetype)init {
  self = [super init];
  if (self) {
    _frameSemaphore = dispatch_semaphore_create(0);
    _stopped = NO;
  }
  return self;
}

- (void)stream:(SCStream*)stream
    didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
                   ofType:(SCStreamOutputType)type {
  if (type != SCStreamOutputTypeScreen || _stopped) {
    return;
  }
  if (!CMSampleBufferIsValid(sampleBuffer)) {
    return;
  }

  CFArrayRef attachments =
      CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, false);
  if (attachments && CFArrayGetCount(attachments) > 0) {
    CFDictionaryRef attachmentsDict =
        (CFDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
    NSDictionary* dict = (__bridge NSDictionary*)attachmentsDict;
    NSNumber* statusNum = dict[SCStreamFrameInfoStatus];
    if (statusNum) {
      SCFrameStatus status = (SCFrameStatus)[statusNum integerValue];
      if (status != SCFrameStatusComplete && status != SCFrameStatusStarted) {
        return;
      }
    }
  }

  CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
  if (!imageBuffer) {
    return;
  }

  CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
  void* baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
  size_t width = CVPixelBufferGetWidth(imageBuffer);
  size_t height = CVPixelBufferGetHeight(imageBuffer);
  size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
  size_t dataSize = bytesPerRow * height;

  if (baseAddress && dataSize > 0) {
    NSMutableData* frameData =
        [NSMutableData dataWithBytes:baseAddress length:dataSize];
    @synchronized(self) {
      _latestFrame = frameData;
      _frameWidth = (int)width;
      _frameHeight = (int)height;
      _bytesPerRow = (int)bytesPerRow;
    }
    dispatch_semaphore_signal(_frameSemaphore);
  }
  CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
}
@end

static NSMutableDictionary<NSNumber*, SCStream*>* _streamRegistry = nil;
static NSMutableDictionary<NSNumber*, StreamFrameHandler*>* _handlerRegistry = nil;
static int64_t _nextStreamId = 1;

static void ensureStreamRegistry(void) {
  if (_streamRegistry == nil) {
    _streamRegistry = [NSMutableDictionary dictionary];
    _handlerRegistry = [NSMutableDictionary dictionary];
  }
}

/// Creates and starts a capture stream.
/// Returns stream_id on success, 0 on error.
int64_t stream_create_and_start(int64_t filter_id, int width, int height) {
  ensureCoreGraphicsInit();
  ensureStreamRegistry();

  SCContentFilter* filter = get_content_filter(filter_id);
  if (!filter) {
    return 0;
  }

  SCStreamConfiguration* config = [[SCStreamConfiguration alloc] init];
  if (width > 0 && height > 0) {
    config.width = width;
    config.height = height;
  }
  config.minimumFrameInterval = CMTimeMake(1, 60);
  config.queueDepth = 5;

  StreamFrameHandler* handler = [[StreamFrameHandler alloc] init];
  SCStream* stream =
      [[SCStream alloc] initWithFilter:filter
                        configuration:config
                             delegate:nil];

  NSError* addError = nil;
  dispatch_queue_t queue =
      dispatch_queue_create("com.screencapturekit.frame", DISPATCH_QUEUE_SERIAL);
  [stream addStreamOutput:handler
                    type:SCStreamOutputTypeScreen
        sampleHandlerQueue:queue
                     error:&addError];
  if (addError) {
    return 0;
  }

  __block BOOL startSuccess = NO;
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  [stream startCaptureWithCompletionHandler:^(NSError* _Nullable error) {
    startSuccess = (error == nil);
    dispatch_semaphore_signal(sem);
  }];
  dispatch_semaphore_wait(sem,
                         dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
  if (!startSuccess) {
    return 0;
  }

  int64_t streamId;
  @synchronized(_streamRegistry) {
    streamId = _nextStreamId++;
    _streamRegistry[@(streamId)] = stream;
    _handlerRegistry[@(streamId)] = handler;
  }
  return streamId;
}

/// Returns malloc'd JSON string. On success: {"error":false,"bgraBase64":"...",
/// "width":N,"height":N,"bytesPerRow":N}. On error: {"error":true,...}.
/// Caller must free. Blocks until frame available or timeout.
char* stream_get_next_frame(int64_t stream_id, int64_t timeout_ms) {
  if (stream_id <= 0 || _handlerRegistry == nil) {
    return NULL;
  }

  StreamFrameHandler* handler = _handlerRegistry[@(stream_id)];
  if (!handler) {
    return NULL;
  }

  int64_t timeoutNsec = (timeout_ms > 0 ? timeout_ms : 5000) * NSEC_PER_MSEC;
  long waitResult = dispatch_semaphore_wait(
      handler.frameSemaphore,
      dispatch_time(DISPATCH_TIME_NOW, timeoutNsec));

  if (waitResult != 0) {
    return NULL;
  }

  NSMutableData* frameData = nil;
  int frameWidth = 0, frameHeight = 0, bytesPerRow = 0;
  @synchronized(handler) {
    frameData = handler.latestFrame;
    frameWidth = handler.frameWidth;
    frameHeight = handler.frameHeight;
    bytesPerRow = handler.bytesPerRow;
    handler.latestFrame = nil;
  }

  if (!frameData || frameData.length == 0) {
    return NULL;
  }

  NSString* base64 = [frameData base64EncodedStringWithOptions:0];
  NSDictionary* root = @{
    @"error" : @NO,
    @"bgraBase64" : base64 ?: @"",
    @"width" : @(frameWidth),
    @"height" : @(frameHeight),
    @"bytesPerRow" : @(bytesPerRow)
  };
  NSData* data = [NSJSONSerialization dataWithJSONObject:root options:0 error:nil];
  if (!data) {
    return NULL;
  }
  NSString* str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  return strdup(str.UTF8String);
}

/// Stops and releases a stream.
void stream_stop_and_release(int64_t stream_id) {
  if (stream_id <= 0 || _streamRegistry == nil) {
    return;
  }

  SCStream* stream = nil;
  StreamFrameHandler* handler = nil;
  @synchronized(_streamRegistry) {
    stream = _streamRegistry[@(stream_id)];
    handler = _handlerRegistry[@(stream_id)];
    [_streamRegistry removeObjectForKey:@(stream_id)];
    [_handlerRegistry removeObjectForKey:@(stream_id)];
  }

  if (handler) {
    handler.stopped = YES;
  }
  if (stream) {
    [stream stopCaptureWithCompletionHandler:^(NSError* _Nullable error){
    }];
  }
}
