#import "content_filter.h"
#import <ScreenCaptureKit/ScreenCaptureKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <IOSurface/IOSurface.h>
#include <stdio.h>
#include <string.h>

#define STREAM_DEBUG 0

#if __MAC_OS_X_VERSION_MIN_REQUIRED < 120300
#error "ScreenCaptureKit requires macOS 12.3 or newer"
#endif

static void ensureCoreGraphicsInit(void) {
  (void)CGMainDisplayID();
}

@interface StreamFrameHandler : NSObject <SCStreamOutput>
@property (nonatomic, strong) NSString* latestFrameJson;
@property (nonatomic, strong) dispatch_semaphore_t frameSemaphore;
@property (nonatomic, assign) BOOL stopped;
@property (nonatomic, strong) NSLock* lock;
@end

@implementation StreamFrameHandler
- (instancetype)init {
  self = [super init];
  if (self) {
    _frameSemaphore = dispatch_semaphore_create(0);
    _stopped = NO;
    _lock = [[NSLock alloc] init];
  }
  return self;
}

- (void)stream:(SCStream*)stream
    didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
                   ofType:(SCStreamOutputType)type {
  if (STREAM_DEBUG) fprintf(stderr, "[SCStream] callback type=%d stopped=%d\n", (int)type, _stopped);
  if (type != SCStreamOutputTypeScreen || _stopped) {
    return;
  }
  if (!CMSampleBufferIsValid(sampleBuffer)) {
    if (STREAM_DEBUG) fprintf(stderr, "[SCStream] sample buffer invalid\n");
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
      if (STREAM_DEBUG) fprintf(stderr, "[SCStream] status=%ld\n", (long)[statusNum integerValue]);
      // Accept both Complete and Started (first frame after stream start).
      if (status != SCFrameStatusComplete && status != SCFrameStatusStarted) {
        return;
      }
    }
  }

  CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
  if (!imageBuffer) {
    return;
  }

  size_t width = CVPixelBufferGetWidth(imageBuffer);
  size_t height = CVPixelBufferGetHeight(imageBuffer);
  size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
  size_t dataSize = bytesPerRow * height;
  void* baseAddress = NULL;

  CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
  baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
  if (STREAM_DEBUG) fprintf(stderr, "[SCStream] %zux%zu bpr=%zu baseAddr=%p\n",
      width, height, bytesPerRow, baseAddress);

  // ScreenCaptureKit uses IOSurface-backed CVPixelBuffers; baseAddress is often
  // NULL. Fall back to IOSurface for CPU access.
  if (!baseAddress) {
    IOSurfaceRef surfaceRef = CVPixelBufferGetIOSurface(imageBuffer);
    if (surfaceRef) {
      IOSurfaceLock((IOSurfaceRef)surfaceRef, kIOSurfaceLockReadOnly, NULL);
      baseAddress = IOSurfaceGetBaseAddress((IOSurfaceRef)surfaceRef);
      if (baseAddress && dataSize > 0) {
        NSMutableData* frameData =
            [NSMutableData dataWithBytes:baseAddress length:dataSize];
        IOSurfaceUnlock((IOSurfaceRef)surfaceRef, kIOSurfaceLockReadOnly, NULL);
        CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
        NSString* base64 = [frameData base64EncodedStringWithOptions:0];
        NSDictionary* root = @{
          @"error" : @NO,
          @"bgraBase64" : base64 ?: @"",
          @"width" : @((int)width),
          @"height" : @((int)height),
          @"bytesPerRow" : @((int)bytesPerRow)
        };
        NSData* jsonData = [NSJSONSerialization dataWithJSONObject:root options:0 error:nil];
        NSString* jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        [_lock lock];
        _latestFrameJson = jsonStr;
        [_lock unlock];
        dispatch_semaphore_signal(_frameSemaphore);
        return;
      }
      IOSurfaceUnlock((IOSurfaceRef)surfaceRef, kIOSurfaceLockReadOnly, NULL);
    }
    CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
  } else if (dataSize > 0) {
    NSMutableData* frameData =
        [NSMutableData dataWithBytes:baseAddress length:dataSize];
    CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
    NSString* base64 = [frameData base64EncodedStringWithOptions:0];
    NSDictionary* root = @{
      @"error" : @NO,
      @"bgraBase64" : base64 ?: @"",
      @"width" : @((int)width),
      @"height" : @((int)height),
      @"bytesPerRow" : @((int)bytesPerRow)
    };
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:root options:0 error:nil];
    NSString* jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    [_lock lock];
    _latestFrameJson = jsonStr;
    [_lock unlock];
    if (STREAM_DEBUG) fprintf(stderr, "[SCStream] SIGNAL semaphore\n");
    dispatch_semaphore_signal(_frameSemaphore);
  } else {
    CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
  }
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
/// frame_rate: target fps; 0 or invalid uses 60.
/// src_x, src_y, src_width, src_height: source rect in content points; if
/// src_width > 0 and src_height > 0, config.sourceRect is set for region capture.
/// shows_cursor: 1 to include cursor in capture, 0 to hide.
/// Returns stream_id on success, 0 on error.
int64_t stream_create_and_start(int64_t filter_id, int width, int height,
                                int frame_rate,
                                double src_x, double src_y,
                                double src_width, double src_height,
                                int shows_cursor) {
  ensureCoreGraphicsInit();
  ensureStreamRegistry();

  SCContentFilter* filter = get_content_filter(filter_id);
  if (!filter) {
    return 0;
  }

  int fps = (frame_rate > 0 && frame_rate <= 120) ? frame_rate : 60;
  SCStreamConfiguration* config = [[SCStreamConfiguration alloc] init];
  if (width > 0 && height > 0) {
    config.width = width;
    config.height = height;
  }
  if (src_width > 0 && src_height > 0) {
    config.sourceRect = CGRectMake(src_x, src_y, src_width, src_height);
  }
  config.showsCursor = (shows_cursor != 0);
  config.minimumFrameInterval = CMTimeMake(1, fps);
  config.queueDepth = 5;

  StreamFrameHandler* handler = [[StreamFrameHandler alloc] init];
  SCStream* stream =
      [[SCStream alloc] initWithFilter:filter
                        configuration:config
                             delegate:nil];

  NSError* addError = nil;
  // Use a dedicated serial queue. Dart CLI does not pump the main run loop,
  // so dispatch_get_main_queue() callbacks never run. A custom queue has its
  // own thread and does not depend on the main thread.
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
  if (STREAM_DEBUG) fprintf(stderr, "[SCStream] get_next_frame stream_id=%lld\n", (long long)stream_id);
  if (stream_id <= 0 || _handlerRegistry == nil) {
    return NULL;
  }

  StreamFrameHandler* handler = _handlerRegistry[@(stream_id)];
  if (!handler) {
    if (STREAM_DEBUG) fprintf(stderr, "[SCStream] handler not found\n");
    return NULL;
  }

  if (STREAM_DEBUG) fprintf(stderr, "[SCStream] waiting on semaphore...\n");
  int64_t timeoutNsec = (timeout_ms > 0 ? timeout_ms : 5000) * NSEC_PER_MSEC;
  long waitResult = dispatch_semaphore_wait(
      handler.frameSemaphore,
      dispatch_time(DISPATCH_TIME_NOW, timeoutNsec));

  if (waitResult != 0) {
    if (STREAM_DEBUG) fprintf(stderr, "[SCStream] wait timeout\n");
    return NULL;
  }

  if (STREAM_DEBUG) fprintf(stderr, "[SCStream] got frame from semaphore\n");
  NSString* jsonStr = nil;
  [handler.lock lock];
  jsonStr = handler.latestFrameJson;
  handler.latestFrameJson = nil;
  [handler.lock unlock];

  if (!jsonStr || jsonStr.length == 0) {
    return NULL;
  }
  return strdup(jsonStr.UTF8String);
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
