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

/// Last stream error (set when stream_create_and_start fails). Cleared when read.
static NSString* _lastStreamErrorDomain = nil;
static NSInteger _lastStreamErrorCode = 0;
static NSString* _lastStreamErrorDescription = nil;
static NSLock* _lastStreamErrorLock = nil;

static void setLastStreamError(NSError* _Nullable error) {
  if (_lastStreamErrorLock == nil) {
    _lastStreamErrorLock = [[NSLock alloc] init];
  }
  [_lastStreamErrorLock lock];
  if (error) {
    _lastStreamErrorDomain = [error.domain copy];
    _lastStreamErrorCode = error.code;
    _lastStreamErrorDescription = [error.localizedDescription copy];
  } else {
    _lastStreamErrorDomain = @"";
    _lastStreamErrorCode = 0;
    _lastStreamErrorDescription = @"";
  }
  [_lastStreamErrorLock unlock];
}

static void setLastStreamErrorFromStrings(NSString* domain, NSInteger code, NSString* description) {
  if (_lastStreamErrorLock == nil) {
    _lastStreamErrorLock = [[NSLock alloc] init];
  }
  [_lastStreamErrorLock lock];
  _lastStreamErrorDomain = domain ? [domain copy] : @"";
  _lastStreamErrorCode = code;
  _lastStreamErrorDescription = description ? [description copy] : @"";
  [_lastStreamErrorLock unlock];
}

/// Returns malloc'd JSON string for last stream error, or NULL if none. Caller must free. Clears the stored error.
char* stream_get_last_error(void) {
  if (_lastStreamErrorLock == nil) {
    return NULL;
  }
  [_lastStreamErrorLock lock];
  NSString* domain = _lastStreamErrorDomain;
  NSString* desc = _lastStreamErrorDescription;
  NSInteger code = _lastStreamErrorCode;
  _lastStreamErrorDomain = nil;
  _lastStreamErrorCode = 0;
  _lastStreamErrorDescription = nil;
  [_lastStreamErrorLock unlock];

  if (domain == nil && desc == nil) {
    return NULL;
  }
  NSDictionary* errDict = @{
    @"error" : @YES,
    @"domain" : domain ?: @"",
    @"code" : @(code),
    @"localizedDescription" : desc ?: @""
  };
  NSData* data = [NSJSONSerialization dataWithJSONObject:errDict options:0 error:nil];
  if (!data || data.length == 0) {
    return NULL;
  }
  NSString* jsonStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  return strdup(jsonStr.UTF8String);
}

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
/// queue_depth: frame queue depth (1–8); 0 or invalid uses 5.
/// Returns stream_id on success, 0 on error.
int64_t stream_create_and_start(int64_t filter_id, int width, int height,
                                int frame_rate,
                                double src_x, double src_y,
                                double src_width, double src_height,
                                int shows_cursor, int queue_depth) {
  ensureCoreGraphicsInit();
  ensureStreamRegistry();

  SCContentFilter* filter = get_content_filter(filter_id);
  if (!filter) {
    setLastStreamErrorFromStrings(@"com.screencapturekit.bridge", -1,
                                  @"Invalid or released content filter.");
    return 0;
  }

  int fps = (frame_rate > 0 && frame_rate <= 120) ? frame_rate : 60;
  int depth = (queue_depth >= 1 && queue_depth <= 8) ? queue_depth : 5;
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
  config.queueDepth = depth;

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
    setLastStreamError(addError);
    return 0;
  }

  __block BOOL startSuccess = NO;
  __block NSError* startError = nil;
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  [stream startCaptureWithCompletionHandler:^(NSError* _Nullable error) {
    startSuccess = (error == nil);
    startError = error;
    dispatch_semaphore_signal(sem);
  }];
  dispatch_semaphore_wait(sem,
                         dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
  if (!startSuccess) {
    setLastStreamError(startError);
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

/// Updates configuration of a running stream. Params same as stream_create_and_start.
/// Returns 0 on success, -1 on error (sets last stream error).
int stream_update_configuration(int64_t stream_id, int width, int height,
                                int frame_rate,
                                double src_x, double src_y,
                                double src_width, double src_height,
                                int shows_cursor, int queue_depth) {
  if (stream_id <= 0 || _streamRegistry == nil) {
    setLastStreamErrorFromStrings(@"com.screencapturekit.bridge", -1,
                                  @"Invalid stream id.");
    return -1;
  }

  SCStream* stream = _streamRegistry[@(stream_id)];
  if (!stream) {
    setLastStreamErrorFromStrings(@"com.screencapturekit.bridge", -1,
                                  @"Stream not found or already stopped.");
    return -1;
  }

  int fps = (frame_rate > 0 && frame_rate <= 120) ? frame_rate : 60;
  int depth = (queue_depth >= 1 && queue_depth <= 8) ? queue_depth : 5;
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
  config.queueDepth = depth;

  __block BOOL success = NO;
  __block NSError* updateError = nil;
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  [stream updateConfiguration:config
          completionHandler:^(NSError* _Nullable error) {
    success = (error == nil);
    updateError = error;
    dispatch_semaphore_signal(sem);
  }];
  dispatch_semaphore_wait(sem,
                         dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
  if (!success) {
    setLastStreamError(updateError);
    return -1;
  }
  return 0;
}

/// Updates content filter of a running stream. Returns 0 on success, -1 on error.
int stream_update_content_filter(int64_t stream_id, int64_t filter_id) {
  if (stream_id <= 0 || _streamRegistry == nil) {
    setLastStreamErrorFromStrings(@"com.screencapturekit.bridge", -1,
                                  @"Invalid stream id.");
    return -1;
  }

  SCStream* stream = _streamRegistry[@(stream_id)];
  if (!stream) {
    setLastStreamErrorFromStrings(@"com.screencapturekit.bridge", -1,
                                  @"Stream not found or already stopped.");
    return -1;
  }

  SCContentFilter* filter = get_content_filter(filter_id);
  if (!filter) {
    setLastStreamErrorFromStrings(@"com.screencapturekit.bridge", -1,
                                  @"Invalid or released content filter.");
    return -1;
  }

  __block BOOL success = NO;
  __block NSError* updateError = nil;
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  [stream updateContentFilter:filter
          completionHandler:^(NSError* _Nullable error) {
    success = (error == nil);
    updateError = error;
    dispatch_semaphore_signal(sem);
  }];
  dispatch_semaphore_wait(sem,
                         dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
  if (!success) {
    setLastStreamError(updateError);
    return -1;
  }
  return 0;
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
