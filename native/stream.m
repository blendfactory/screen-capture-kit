#import "content_filter.h"
#import <ScreenCaptureKit/ScreenCaptureKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <IOSurface/IOSurface.h>
#import <AudioToolbox/AudioToolbox.h>
#include <stdio.h>
#include <string.h>

#define STREAM_DEBUG 0

#if __MAC_OS_X_VERSION_MIN_REQUIRED < 120300
#error "ScreenCaptureKit requires macOS 12.3 or newer"
#endif

// Bounded queue of raw BGRA frame buffers.  Keeps Obj-C object churn to zero
// in the hot path so the callback can run in < 2 ms even at high resolutions.
#define MAX_RAW_FRAME_QUEUE 64

// Each queued buffer layout (all little-endian):
//   [0..3]   int32_t  width
//   [4..7]   int32_t  height
//   [8..11]  int32_t  bytesPerRow
//   [12..15] int32_t  dataSize   (== bytesPerRow * height)
//   [16..]   uint8_t  pixels[dataSize]
#define RAW_FRAME_HEADER_SIZE 16

static void ensureCoreGraphicsInit(void) {
  (void)CGMainDisplayID();
}

@interface StreamFrameHandler : NSObject <SCStreamOutput> {
  @public
  void* _frameQueue[MAX_RAW_FRAME_QUEUE];
  int   _frameQueueCount;
}
@property (nonatomic, strong) dispatch_semaphore_t frameSemaphore;
@property (nonatomic, assign) BOOL stopped;
@property (nonatomic, strong) NSLock* lock;
@end

@implementation StreamFrameHandler
- (instancetype)init {
  self = [super init];
  if (self) {
    memset(_frameQueue, 0, sizeof(_frameQueue));
    _frameQueueCount = 0;
    _frameSemaphore = dispatch_semaphore_create(0);
    _stopped = NO;
    _lock = [[NSLock alloc] init];
  }
  return self;
}

- (void)dealloc {
  for (int i = 0; i < _frameQueueCount; i++) {
    free(_frameQueue[i]);
  }
  [super dealloc];
}

- (void)_enqueueRawData:(const void*)src
               dataSize:(size_t)dataSize
                  width:(size_t)width
                 height:(size_t)height
            bytesPerRow:(size_t)bytesPerRow {
  int32_t totalSize = RAW_FRAME_HEADER_SIZE + (int32_t)dataSize;
  void* buf = malloc(totalSize);
  if (!buf) return;

  int32_t w   = (int32_t)width;
  int32_t h   = (int32_t)height;
  int32_t bpr = (int32_t)bytesPerRow;
  int32_t ds  = (int32_t)dataSize;
  memcpy(buf,      &w,   4);
  memcpy(buf + 4,  &h,   4);
  memcpy(buf + 8,  &bpr, 4);
  memcpy(buf + 12, &ds,  4);
  memcpy(buf + RAW_FRAME_HEADER_SIZE, src, dataSize);

  [_lock lock];
  if (_frameQueueCount >= MAX_RAW_FRAME_QUEUE) {
    free(_frameQueue[0]);
    memmove(&_frameQueue[0], &_frameQueue[1],
            sizeof(void*) * (size_t)(_frameQueueCount - 1));
    _frameQueueCount--;
  }
  _frameQueue[_frameQueueCount] = buf;
  _frameQueueCount++;
  [_lock unlock];
  dispatch_semaphore_signal(_frameSemaphore);
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

  if (!baseAddress) {
    IOSurfaceRef surfaceRef = CVPixelBufferGetIOSurface(imageBuffer);
    if (surfaceRef) {
      IOSurfaceLock(surfaceRef, kIOSurfaceLockReadOnly, NULL);
      baseAddress = IOSurfaceGetBaseAddress(surfaceRef);
      if (baseAddress && dataSize > 0) {
        [self _enqueueRawData:baseAddress dataSize:dataSize
                        width:width height:height bytesPerRow:bytesPerRow];
      }
      IOSurfaceUnlock(surfaceRef, kIOSurfaceLockReadOnly, NULL);
      CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
      return;
    }
    CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
  } else if (dataSize > 0) {
    [self _enqueueRawData:baseAddress dataSize:dataSize
                    width:width height:height bytesPerRow:bytesPerRow];
    CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
  } else {
    CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
  }
}
@end

/// Interleave PCM for WAV/Dart: ScreenCaptureKit may deliver non-interleaved
/// (planar) buffers (one AudioBuffer per channel). Using only mBuffers[0]
/// then halving the payload breaks duration (2× speed if WAV still claims
/// >1 channel, or half-length mic when amix pads with silence).
///
/// Some streams omit kAudioFormatFlagIsNonInterleaved but still use one buffer
/// per channel; detect that by layout (mNumberBuffers == mChannelsPerFrame,
/// each buffer single-channel, equal sizes).
static NSMutableData* BuildInterleavedPCM(const AudioBufferList* bufferList,
                                         const AudioStreamBasicDescription* asbd,
                                         NSString* __autoreleasing* outFormatId) {
  *outFormatId = @"raw";
  if (!bufferList || bufferList->mNumberBuffers == 0 || !asbd) {
    return nil;
  }

  UInt32 numChannels = asbd->mChannelsPerFrame;
  BOOL isNonInterleaved = (asbd->mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0;

  if (asbd->mFormatID != kAudioFormatLinearPCM) {
    AudioBuffer buf = bufferList->mBuffers[0];
    if (buf.mData && buf.mDataByteSize > 0) {
      return [NSMutableData dataWithBytes:buf.mData length:buf.mDataByteSize];
    }
    return nil;
  }

  if (asbd->mFormatFlags & kAudioFormatFlagIsFloat) {
    *outFormatId = @"f32";
  } else if (asbd->mBitsPerChannel == 16) {
    *outFormatId = @"s16";
  }

  UInt32 bits = asbd->mBitsPerChannel;
  size_t bytesPerSample = bits / 8;

  BOOL buffersMatchChannelCount =
      (numChannels > 0 && bufferList->mNumberBuffers == numChannels);
  BOOL eachBufferAtMostOneChannel = YES;
  for (UInt32 i = 0; i < bufferList->mNumberBuffers; i++) {
    UInt32 perBufCh = bufferList->mBuffers[i].mNumberChannels;
    if (perBufCh > 1) {
      eachBufferAtMostOneChannel = NO;
      break;
    }
  }
  /// Microphone output may be planar without setting IsNonInterleaved.
  BOOL planarByLayout = buffersMatchChannelCount && numChannels > 1 &&
      eachBufferAtMostOneChannel && bufferList->mNumberBuffers > 1;
  BOOL shouldPlanarInterleave =
      (isNonInterleaved && buffersMatchChannelCount) || planarByLayout;

  if (shouldPlanarInterleave && bytesPerSample > 0) {
    size_t frames = bufferList->mBuffers[0].mDataByteSize / bytesPerSample;
    if (frames == 0) {
      return nil;
    }

    for (UInt32 ch = 0; ch < numChannels; ch++) {
      const AudioBuffer* b = &bufferList->mBuffers[ch];
      if (!b->mData) {
        return nil;
      }
      size_t chFrames = b->mDataByteSize / bytesPerSample;
      if (chFrames != frames) {
        return nil;
      }
    }

    NSUInteger capacity = (NSUInteger)(frames * bytesPerSample * numChannels);
    NSMutableData* out = [NSMutableData dataWithCapacity:capacity];

    if (asbd->mFormatFlags & kAudioFormatFlagIsFloat) {
      for (size_t f = 0; f < frames; f++) {
        for (UInt32 ch = 0; ch < numChannels; ch++) {
          float sample = ((const float*)bufferList->mBuffers[ch].mData)[f];
          [out appendBytes:&sample length:sizeof(float)];
        }
      }
    } else if (bits == 16) {
      for (size_t f = 0; f < frames; f++) {
        for (UInt32 ch = 0; ch < numChannels; ch++) {
          int16_t sample = ((const int16_t*)bufferList->mBuffers[ch].mData)[f];
          [out appendBytes:&sample length:sizeof(int16_t)];
        }
      }
    } else {
      return nil;
    }
    return out;
  }

  /// Mono split across several 1-channel buffers (seen on some microphone
  /// CMSampleBuffer layouts). Copying only mBuffers[0] halves wall-clock audio.
  if (numChannels == 1 && bufferList->mNumberBuffers > 1 &&
      asbd->mFormatID == kAudioFormatLinearPCM && bytesPerSample > 0) {
    BOOL okMonoBuffers = YES;
    for (UInt32 i = 0; i < bufferList->mNumberBuffers; i++) {
      if (bufferList->mBuffers[i].mNumberChannels > 1) {
        okMonoBuffers = NO;
        break;
      }
    }
    if (okMonoBuffers) {
      NSMutableData* out = [NSMutableData data];
      for (UInt32 i = 0; i < bufferList->mNumberBuffers; i++) {
        const AudioBuffer* b = &bufferList->mBuffers[i];
        if (b->mData && b->mDataByteSize > 0) {
          [out appendBytes:b->mData length:b->mDataByteSize];
        }
      }
      if (out.length > 0) {
        return out;
      }
    }
  }

  AudioBuffer buf = bufferList->mBuffers[0];
  if (buf.mData && buf.mDataByteSize > 0) {
    return [NSMutableData dataWithBytes:buf.mData length:buf.mDataByteSize];
  }
  return nil;
}

/// Adds CMSampleBuffer presentation timestamp and duration (seconds) for Dart
/// timeline alignment. Keys are omitted when CoreMedia reports invalid times.
/// Ref: CMSampleBufferGetPresentationTimeStamp, SCStream media timebase.
static void SCRootAddSampleTiming(NSMutableDictionary* root,
                                  CMSampleBufferRef sampleBuffer) {
  CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
  if (CMTIME_IS_VALID(pts) && !CMTIME_IS_INDEFINITE(pts)) {
    root[@"presentationTimeSeconds"] = @(CMTimeGetSeconds(pts));
  }
  CMTime dur = CMSampleBufferGetDuration(sampleBuffer);
  if (CMTIME_IS_VALID(dur) && !CMTIME_IS_INDEFINITE(dur) && dur.value != 0) {
    root[@"durationSeconds"] = @(CMTimeGetSeconds(dur));
  }
}

@interface StreamAudioHandler : NSObject <SCStreamOutput>
@property (nonatomic, strong) NSMutableArray<NSString*>* queue;
@property (nonatomic, strong) NSLock* lock;
@property (nonatomic, strong) dispatch_semaphore_t semaphore;
@property (nonatomic, assign) BOOL stopped;
@end

@implementation StreamAudioHandler
- (instancetype)init {
  self = [super init];
  if (self) {
    _queue = [NSMutableArray array];
    _lock = [[NSLock alloc] init];
    _semaphore = dispatch_semaphore_create(0);
    _stopped = NO;
  }
  return self;
}

- (void)stream:(SCStream*)stream
    didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
                   ofType:(SCStreamOutputType)type {
  if (@available(macos 13.0, *)) {
    if (type != SCStreamOutputTypeAudio || _stopped) {
      return;
    }
  } else {
    return;
  }
  if (!CMSampleBufferIsValid(sampleBuffer)) {
    return;
  }

  CMFormatDescriptionRef formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer);
  if (!formatDesc) {
    return;
  }
  const AudioStreamBasicDescription* asbd =
      CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc);
  if (!asbd) {
    return;
  }

  size_t bufferListSizeNeeded = 0;
  OSStatus status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
      sampleBuffer,
      &bufferListSizeNeeded,
      NULL,
      0,
      NULL,
      NULL,
      kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
      NULL);
  if (status != noErr || bufferListSizeNeeded == 0) {
    return;
  }

  char* bufferListBytes = (char*)malloc(bufferListSizeNeeded);
  if (!bufferListBytes) {
    return;
  }
  AudioBufferList* bufferList = (AudioBufferList*)bufferListBytes;
  CMBlockBufferRef blockBuffer = NULL;

  status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
      sampleBuffer,
      NULL,
      bufferList,
      bufferListSizeNeeded,
      NULL,
      NULL,
      kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
      &blockBuffer);
  if (status != noErr || !blockBuffer) {
    free(bufferListBytes);
    return;
  }

  UInt32 numChannels = asbd->mChannelsPerFrame;
  Float64 sampleRate = asbd->mSampleRate;
  NSString* formatId = @"raw";

  NSMutableData* pcmData = BuildInterleavedPCM(bufferList, asbd, &formatId);

  if (blockBuffer) {
    CFRelease(blockBuffer);
  }
  free(bufferListBytes);

  if (!pcmData || pcmData.length == 0) {
    return;
  }

  NSString* base64 = [pcmData base64EncodedStringWithOptions:0];
  CMItemCount numSamples = CMSampleBufferGetNumSamples(sampleBuffer);
  NSMutableDictionary* root = [NSMutableDictionary dictionaryWithDictionary:@{
    @"error" : @NO,
    @"pcmBase64" : base64 ?: @"",
    @"sampleRate" : @(sampleRate),
    @"channelCount" : @((int)numChannels),
    @"format" : formatId ?: @"raw",
    @"byteCount" : @((int)pcmData.length),
    @"numSamples" : @((int)numSamples)
  }];
  SCRootAddSampleTiming(root, sampleBuffer);
  NSData* jsonData = [NSJSONSerialization dataWithJSONObject:root options:0 error:nil];
  NSString* jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

  [_lock lock];
  [_queue addObject:jsonStr];
  [_lock unlock];
  dispatch_semaphore_signal(_semaphore);
}
@end

@interface StreamMicrophoneHandler : NSObject <SCStreamOutput>
@property (nonatomic, strong) NSMutableArray<NSString*>* queue;
@property (nonatomic, strong) NSLock* lock;
@property (nonatomic, strong) dispatch_semaphore_t semaphore;
@property (nonatomic, assign) BOOL stopped;
@end

@implementation StreamMicrophoneHandler
- (instancetype)init {
  self = [super init];
  if (self) {
    _queue = [NSMutableArray array];
    _lock = [[NSLock alloc] init];
    _semaphore = dispatch_semaphore_create(0);
    _stopped = NO;
  }
  return self;
}

- (void)stream:(SCStream*)stream
    didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
                   ofType:(SCStreamOutputType)type {
  if (@available(macos 15.0, *)) {
    if (type != SCStreamOutputTypeMicrophone || _stopped) {
      return;
    }
  } else {
    return;
  }
  if (!CMSampleBufferIsValid(sampleBuffer)) {
    return;
  }

  CMFormatDescriptionRef formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer);
  if (!formatDesc) {
    return;
  }
  const AudioStreamBasicDescription* asbd =
      CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc);
  if (!asbd) {
    return;
  }

  size_t bufferListSizeNeeded = 0;
  OSStatus status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
      sampleBuffer,
      &bufferListSizeNeeded,
      NULL,
      0,
      NULL,
      NULL,
      kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
      NULL);
  if (status != noErr || bufferListSizeNeeded == 0) {
    return;
  }

  char* bufferListBytes = (char*)malloc(bufferListSizeNeeded);
  if (!bufferListBytes) {
    return;
  }
  AudioBufferList* bufferList = (AudioBufferList*)bufferListBytes;
  CMBlockBufferRef blockBuffer = NULL;

  status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
      sampleBuffer,
      NULL,
      bufferList,
      bufferListSizeNeeded,
      NULL,
      NULL,
      kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
      &blockBuffer);
  if (status != noErr || !blockBuffer) {
    free(bufferListBytes);
    return;
  }

  UInt32 numChannels = asbd->mChannelsPerFrame;
  Float64 sampleRate = asbd->mSampleRate;
  NSString* formatId = @"raw";
  NSMutableData* pcmData = BuildInterleavedPCM(bufferList, asbd, &formatId);

  // Microphone: recover full PCM when BuildInterleavedPCM under-reads (mono
  // split across buffers with per-buffer mNumberChannels that prevented the
  // mono-concat branch, or when buffer list total exceeds pcm length).
  if (pcmData && asbd->mFormatID == kAudioFormatLinearPCM) {
    size_t listedTotal = 0;
    CMItemCount nFrames = CMSampleBufferGetNumSamples(sampleBuffer);
    UInt32 bits = asbd->mBitsPerChannel;
    size_t bps = bits / 8;
    size_t expectedBytes =
        (size_t)nFrames * (size_t)numChannels * (bps > 0 ? bps : 0);
    for (UInt32 i = 0; i < bufferList->mNumberBuffers; i++) {
      listedTotal += bufferList->mBuffers[i].mDataByteSize;
    }
    if (numChannels == 1 && listedTotal > pcmData.length) {
      NSMutableData* concat = [NSMutableData data];
      for (UInt32 i = 0; i < bufferList->mNumberBuffers; i++) {
        const AudioBuffer* b = &bufferList->mBuffers[i];
        if (b->mData && b->mDataByteSize > 0) {
          [concat appendBytes:b->mData length:b->mDataByteSize];
        }
      }
      if (concat.length > pcmData.length) {
        pcmData = concat;
      }
    }

    if (nFrames > 0 && bps > 0 && numChannels > 0) {
      if (pcmData.length + 8 < expectedBytes) {
        CMBlockBufferRef dataBuf = CMSampleBufferGetDataBuffer(sampleBuffer);
        if (dataBuf) {
          size_t bbLen = CMBlockBufferGetDataLength(dataBuf);
          size_t n = expectedBytes <= bbLen ? expectedBytes : bbLen;
          if (n > pcmData.length) {
            NSMutableData* raw = [NSMutableData dataWithLength:n];
            OSStatus cst =
                CMBlockBufferCopyDataBytes(dataBuf, 0, n, raw.mutableBytes);
            if (cst == noErr && raw.length > pcmData.length) {
              pcmData = raw;
              if (asbd->mFormatFlags & kAudioFormatFlagIsFloat) {
                formatId = @"f32";
              } else if (bits == 16) {
                formatId = @"s16";
              }
            }
          }
        }
      }
    }
  }

  if (blockBuffer) {
    CFRelease(blockBuffer);
  }
  free(bufferListBytes);

  if (!pcmData || pcmData.length == 0) {
    return;
  }

  NSString* base64 = [pcmData base64EncodedStringWithOptions:0];
  CMItemCount numSamples = CMSampleBufferGetNumSamples(sampleBuffer);
  NSMutableDictionary* root = [NSMutableDictionary dictionaryWithDictionary:@{
    @"error" : @NO,
    @"pcmBase64" : base64 ?: @"",
    @"sampleRate" : @(sampleRate),
    @"channelCount" : @((int)numChannels),
    @"format" : formatId ?: @"raw",
    @"byteCount" : @((int)pcmData.length),
    @"numSamples" : @((int)numSamples)
  }];
  SCRootAddSampleTiming(root, sampleBuffer);
  NSData* jsonData = [NSJSONSerialization dataWithJSONObject:root options:0 error:nil];
  NSString* jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

  [_lock lock];
  [_queue addObject:jsonStr];
  [_lock unlock];
  dispatch_semaphore_signal(_semaphore);
}
@end

static NSMutableDictionary<NSNumber*, SCStream*>* _streamRegistry = nil;
static NSMutableDictionary<NSNumber*, StreamFrameHandler*>* _handlerRegistry = nil;
static NSMutableDictionary<NSNumber*, StreamAudioHandler*>* _audioHandlerRegistry = nil;
static NSMutableDictionary<NSNumber*, StreamMicrophoneHandler*>* _microphoneHandlerRegistry = nil;
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
    _audioHandlerRegistry = [NSMutableDictionary dictionary];
    _microphoneHandlerRegistry = [NSMutableDictionary dictionary];
  }
}

/// Creates and starts a capture stream.
/// frame_rate: target fps; 0 or invalid uses 60.
/// src_x, src_y, src_width, src_height: source rect in content points; if
/// src_width > 0 and src_height > 0, config.sourceRect is set for region capture.
/// shows_cursor: 1 to include cursor in capture, 0 to hide.
/// queue_depth: frame queue depth (1–8); 0 or invalid uses 5.
/// captures_audio: 1 to capture system audio, 0 to disable.
/// excludes_current_process_audio: 1 to exclude this app's audio from capture.
/// capture_microphone: 1 to include microphone in capture.
/// pixel_format: CVPixelFormatType (OSType); 0 = default. All kCVPixelFormatType_*:
/// https://developer.apple.com/documentation/corevideo/pixel-format-identifiers
/// color_space_name: optional color space name (e.g. kCGColorSpaceSRGB); NULL = default.
/// Returns stream_id on success, 0 on error.
int64_t stream_create_and_start(int64_t filter_id, int width, int height,
                                int frame_rate,
                                double src_x, double src_y,
                                double src_width, double src_height,
                                int shows_cursor, int queue_depth,
                                int captures_audio, int excludes_current_process_audio,
                                int capture_microphone,
                                uint32_t pixel_format, const char* color_space_name) {
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
  if (@available(macos 13.0, *)) {
    config.capturesAudio = (captures_audio != 0);
    config.excludesCurrentProcessAudio = (excludes_current_process_audio != 0);
  }
  if (@available(macos 15.0, *)) {
    config.captureMicrophone = (capture_microphone != 0);
  }
  if (pixel_format != 0) {
    config.pixelFormat = (OSType)pixel_format;
  }
  if (color_space_name != NULL && strlen(color_space_name) > 0) {
    NSString* name = [NSString stringWithUTF8String:color_space_name];
    if (name) {
      config.colorSpaceName = (__bridge CFStringRef)name;
    }
  }

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
    setLastStreamError(addError);
    return 0;
  }

  StreamAudioHandler* audioHandler = nil;
  if (captures_audio) {
    if (@available(macos 13.0, *)) {
      audioHandler = [[StreamAudioHandler alloc] init];
      dispatch_queue_t audioQueue =
          dispatch_queue_create("com.screencapturekit.audio", DISPATCH_QUEUE_SERIAL);
      [stream addStreamOutput:audioHandler
                        type:SCStreamOutputTypeAudio
            sampleHandlerQueue:audioQueue
                         error:&addError];
      if (addError) {
        setLastStreamError(addError);
        return 0;
      }
    }
  }

  StreamMicrophoneHandler* microphoneHandler = nil;
  if (capture_microphone) {
    if (@available(macos 15.0, *)) {
      microphoneHandler = [[StreamMicrophoneHandler alloc] init];
      dispatch_queue_t micQueue =
          dispatch_queue_create("com.screencapturekit.microphone", DISPATCH_QUEUE_SERIAL);
      [stream addStreamOutput:microphoneHandler
                        type:SCStreamOutputTypeMicrophone
            sampleHandlerQueue:micQueue
                         error:&addError];
      if (addError) {
        setLastStreamError(addError);
        return 0;
      }
    }
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
    if (audioHandler) {
      _audioHandlerRegistry[@(streamId)] = audioHandler;
    }
    if (microphoneHandler) {
      _microphoneHandlerRegistry[@(streamId)] = microphoneHandler;
    }
  }
  return streamId;
}

/// Updates configuration of a running stream. Params same as stream_create_and_start.
/// Returns 0 on success, -1 on error (sets last stream error).
int stream_update_configuration(int64_t stream_id, int width, int height,
                                int frame_rate,
                                double src_x, double src_y,
                                double src_width, double src_height,
                                int shows_cursor, int queue_depth,
                                int captures_audio, int excludes_current_process_audio,
                                int capture_microphone,
                                uint32_t pixel_format, const char* color_space_name) {
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
  if (@available(macos 13.0, *)) {
    config.capturesAudio = (captures_audio != 0);
    config.excludesCurrentProcessAudio = (excludes_current_process_audio != 0);
  }
  if (@available(macos 15.0, *)) {
    config.captureMicrophone = (capture_microphone != 0);
  }
  if (pixel_format != 0) {
    config.pixelFormat = (OSType)pixel_format;
  }
  if (color_space_name != NULL && strlen(color_space_name) > 0) {
    NSString* name = [NSString stringWithUTF8String:color_space_name];
    if (name) {
      config.colorSpaceName = (__bridge CFStringRef)name;
    }
  }

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

/// Build SCContentSharingPickerMode option set from JSON array of mode names.
static SCContentSharingPickerMode picker_modes_from_json_array(NSArray* arr) API_AVAILABLE(macos(14.0)) {
  if (!arr || arr.count == 0) return 0;
  SCContentSharingPickerMode modes = 0;
  for (id item in arr) {
    if (![item isKindOfClass:[NSString class]]) continue;
    NSString* s = (NSString*)item;
    if ([s isEqualToString:@"singleDisplay"]) modes |= SCContentSharingPickerModeSingleDisplay;
    else if ([s isEqualToString:@"singleWindow"]) modes |= SCContentSharingPickerModeSingleWindow;
    else if ([s isEqualToString:@"singleApplication"]) modes |= SCContentSharingPickerModeSingleApplication;
    else if ([s isEqualToString:@"multipleWindows"]) modes |= SCContentSharingPickerModeMultipleWindows;
    else if ([s isEqualToString:@"multipleApplications"]) modes |= SCContentSharingPickerModeMultipleApplications;
  }
  return modes;
}

/// Sets the content-sharing picker configuration for a stream (macOS 14+).
/// config_json: NULL or empty = use default (nil). Otherwise JSON object with
/// optional "allowedPickerModes" (array of strings), "allowsChangingSelectedContent" (bool),
/// "excludedBundleIDs" (array of strings), "excludedWindowIDs" (array of ints).
/// Returns 0 on success, -1 on error.
int stream_set_picker_configuration(int64_t stream_id, const char* _Nullable config_json) {
  if (stream_id <= 0 || _streamRegistry == nil) {
    return -1;
  }
  SCStream* stream = _streamRegistry[@(stream_id)];
  if (!stream) {
    return -1;
  }
  if (@available(macOS 14.0, *)) {
    SCContentSharingPickerConfiguration* config = nil;
    if (config_json && config_json[0] != '\0') {
      NSData* data = [NSData dataWithBytes:config_json length:strlen(config_json)];
      NSError* err = nil;
      id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
      if (!err && [parsed isKindOfClass:[NSDictionary class]]) {
        NSDictionary* dict = (NSDictionary*)parsed;
        config = [[SCContentSharingPickerConfiguration alloc] init];
        id modesArr = dict[@"allowedPickerModes"];
        if ([modesArr isKindOfClass:[NSArray class]]) {
          config.allowedPickerModes = picker_modes_from_json_array((NSArray*)modesArr);
        }
        id allowsChange = dict[@"allowsChangingSelectedContent"];
        if ([allowsChange isKindOfClass:[NSNumber class]]) {
          config.allowsChangingSelectedContent = [(NSNumber*)allowsChange boolValue];
        }
        id bundleIds = dict[@"excludedBundleIDs"];
        if ([bundleIds isKindOfClass:[NSArray class]]) {
          NSMutableArray<NSString*>* arr = [NSMutableArray array];
          for (id o in (NSArray*)bundleIds) {
            if ([o isKindOfClass:[NSString class]]) [arr addObject:(NSString*)o];
          }
          config.excludedBundleIDs = arr;
        }
        id windowIds = dict[@"excludedWindowIDs"];
        if ([windowIds isKindOfClass:[NSArray class]]) {
          NSMutableArray<NSNumber*>* arr = [NSMutableArray array];
          for (id o in (NSArray*)windowIds) {
            if ([o isKindOfClass:[NSNumber class]]) [arr addObject:(NSNumber*)o];
          }
          config.excludedWindowIDs = arr;
        }
      }
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-method-access"
    [[SCContentSharingPicker sharedPicker] setConfiguration:config forStream:stream];
#pragma clang diagnostic pop
  } else {
    return -1;
  }
  return 0;
}

/// Returns a malloc'd raw-frame buffer (header + BGRA pixels), or NULL on
/// timeout / error.  Caller must free() the returned pointer.
///
/// Buffer layout (16-byte header, little-endian):
///   [0..3]   int32  width
///   [4..7]   int32  height
///   [8..11]  int32  bytesPerRow
///   [12..15] int32  dataSize
///   [16..]   uint8  pixels[dataSize]
void* stream_get_next_frame(int64_t stream_id, int64_t timeout_ms) {
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
  dispatch_time_t timeout = (timeout_ms > 0)
      ? dispatch_time(DISPATCH_TIME_NOW, timeout_ms * NSEC_PER_MSEC)
      : DISPATCH_TIME_NOW;
  long waitResult = dispatch_semaphore_wait(handler.frameSemaphore, timeout);

  if (waitResult != 0) {
    if (STREAM_DEBUG) fprintf(stderr, "[SCStream] wait timeout\n");
    return NULL;
  }

  if (STREAM_DEBUG) fprintf(stderr, "[SCStream] got frame from semaphore\n");
  void* result = NULL;
  [handler.lock lock];
  if (handler->_frameQueueCount > 0) {
    result = handler->_frameQueue[0];
    memmove(&handler->_frameQueue[0], &handler->_frameQueue[1],
            sizeof(void*) * (size_t)(handler->_frameQueueCount - 1));
    handler->_frameQueueCount--;
  }
  [handler.lock unlock];

  return result;
}

/// Returns malloc'd JSON string for next audio buffer, or NULL on timeout/error.
/// Format: {"error":false,"pcmBase64":"...","sampleRate":N,"channelCount":N,
/// "format":"f32","byteCount":N,"numSamples":N,
/// optional "presentationTimeSeconds","durationSeconds"}.
/// Caller must free.
char* stream_get_next_audio(int64_t stream_id, int64_t timeout_ms) {
  if (stream_id <= 0 || _audioHandlerRegistry == nil) {
    return NULL;
  }

  StreamAudioHandler* handler = _audioHandlerRegistry[@(stream_id)];
  if (!handler) {
    return NULL;
  }

  // Match stream_get_next_frame: timeout_ms <= 0 means non-blocking wait
  // (DISPATCH_TIME_NOW). Dart passes 0 when draining batch tails; using 5 s
  // here starved the mic queue and the isolate event loop.
  dispatch_time_t waitDeadline = (timeout_ms > 0)
      ? dispatch_time(DISPATCH_TIME_NOW, timeout_ms * NSEC_PER_MSEC)
      : DISPATCH_TIME_NOW;
  long waitResult = dispatch_semaphore_wait(handler.semaphore, waitDeadline);

  if (waitResult != 0) {
    return NULL;
  }

  NSString* jsonStr = nil;
  [handler.lock lock];
  if (handler.queue.count > 0) {
    jsonStr = handler.queue.firstObject;
    [handler.queue removeObjectAtIndex:0];
  }
  [handler.lock unlock];

  if (!jsonStr || jsonStr.length == 0) {
    return NULL;
  }
  return strdup(jsonStr.UTF8String);
}

/// Returns malloc'd JSON string for next microphone buffer, or NULL on timeout/error.
/// Same format as stream_get_next_audio. Caller must free.
char* stream_get_next_microphone(int64_t stream_id, int64_t timeout_ms) {
  if (stream_id <= 0 || _microphoneHandlerRegistry == nil) {
    return NULL;
  }

  StreamMicrophoneHandler* handler = _microphoneHandlerRegistry[@(stream_id)];
  if (!handler) {
    return NULL;
  }

  dispatch_time_t waitDeadline = (timeout_ms > 0)
      ? dispatch_time(DISPATCH_TIME_NOW, timeout_ms * NSEC_PER_MSEC)
      : DISPATCH_TIME_NOW;
  long waitResult = dispatch_semaphore_wait(handler.semaphore, waitDeadline);

  if (waitResult != 0) {
    return NULL;
  }

  NSString* jsonStr = nil;
  [handler.lock lock];
  if (handler.queue.count > 0) {
    jsonStr = handler.queue.firstObject;
    [handler.queue removeObjectAtIndex:0];
  }
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
  StreamAudioHandler* audioHandler = nil;
  StreamMicrophoneHandler* microphoneHandler = nil;
  @synchronized(_streamRegistry) {
    stream = _streamRegistry[@(stream_id)];
    handler = _handlerRegistry[@(stream_id)];
    audioHandler = _audioHandlerRegistry[@(stream_id)];
    microphoneHandler = _microphoneHandlerRegistry[@(stream_id)];
    [_streamRegistry removeObjectForKey:@(stream_id)];
    [_handlerRegistry removeObjectForKey:@(stream_id)];
    [_audioHandlerRegistry removeObjectForKey:@(stream_id)];
    [_microphoneHandlerRegistry removeObjectForKey:@(stream_id)];
  }

  if (handler) {
    handler.stopped = YES;
    [handler.lock lock];
    for (int i = 0; i < handler->_frameQueueCount; i++) {
      free(handler->_frameQueue[i]);
    }
    handler->_frameQueueCount = 0;
    [handler.lock unlock];
    dispatch_semaphore_signal(handler.frameSemaphore);
  }
  if (audioHandler) {
    audioHandler.stopped = YES;
  }
  if (microphoneHandler) {
    microphoneHandler.stopped = YES;
  }
  if (stream) {
    // Remove outputs before stopCapture so no more callbacks are delivered.
    // Per Apple docs: removeStreamOutput disconnects outputs before stopping.
    if (handler) {
      NSError* err = nil;
      [stream removeStreamOutput:handler type:SCStreamOutputTypeScreen error:&err];
      (void)err;
    }
    if (audioHandler) {
      if (@available(macos 13.0, *)) {
        NSError* err = nil;
        [stream removeStreamOutput:audioHandler type:SCStreamOutputTypeAudio error:&err];
        (void)err;
      }
    }
    if (microphoneHandler) {
      if (@available(macos 15.0, *)) {
        NSError* err = nil;
        [stream removeStreamOutput:microphoneHandler
                              type:SCStreamOutputTypeMicrophone
                              error:&err];
        (void)err;
      }
    }
    dispatch_semaphore_t stopSem = dispatch_semaphore_create(0);
    [stream stopCaptureWithCompletionHandler:^(NSError* _Nullable error) {
      dispatch_semaphore_signal(stopSem);
    }];
    // Stop cleanup can lag behind when the Dart side is concurrently
    // handling large frame payloads (e.g. isolate writer).
    dispatch_semaphore_wait(
      stopSem,
      dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)
    );
  }
}
