#import "content_filter.h"
#import <ScreenCaptureKit/ScreenCaptureKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>
#include <string.h>

#if __MAC_OS_X_VERSION_MIN_REQUIRED < 120300
#error "ScreenCaptureKit requires macOS 12.3 or newer"
#endif

static void ensureCoreGraphicsInit(void) {
  (void)CGMainDisplayID();
}

/// Captures a screenshot using the filter.

/// Returns a malloc'd JSON string. On success: {"error":false,"pngBase64":"..."}.
/// On error: {"error":true,"domain":"...","code":N,"localizedDescription":"..."}.
/// Caller must free with free().
char* capture_screenshot(int64_t filter_id, int width, int height) {
  ensureCoreGraphicsInit();

  SCContentFilter* filter = get_content_filter(filter_id);
  if (!filter) {
    NSDictionary* errDict = @{
      @"error": @YES,
      @"domain": @"ScreenCaptureKit",
      @"code": @(-2),
      @"localizedDescription": @"Invalid filter id"
    };
    NSData* errData = [NSJSONSerialization dataWithJSONObject:errDict options:0 error:nil];
    if (errData) {
      NSString* errStr = [[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding];
      return strdup(errStr.UTF8String);
    }
    return NULL;
  }

  SCStreamConfiguration* config = [[SCStreamConfiguration alloc] init];
  if (width > 0 && height > 0) {
    config.width = width;
    config.height = height;
  }

  __block char* result = NULL;
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);

  if (@available(macOS 14.0, *)) {
    [SCScreenshotManager captureImageWithFilter:filter
                                 configuration:config
                             completionHandler:^(CGImageRef _Nullable image, NSError* _Nullable error) {
    if (error) {
      NSDictionary* errDict = @{
        @"error": @YES,
        @"domain": error.domain ?: @"",
        @"code": @(error.code),
        @"localizedDescription": error.localizedDescription ?: @""
      };
      NSData* errData = [NSJSONSerialization dataWithJSONObject:errDict options:0 error:nil];
      if (errData) {
        NSString* errStr = [[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding];
        result = strdup(errStr.UTF8String);
      }
      dispatch_semaphore_signal(sem);
      return;
    }

    if (!image) {
      dispatch_semaphore_signal(sem);
      return;
    }

    NSMutableData* pngData = [NSMutableData data];
    CFStringRef pngType = CFSTR("public.png");
    CGImageDestinationRef dest = CGImageDestinationCreateWithData(
        (__bridge CFMutableDataRef)pngData,
        pngType,
        1,
        NULL);
    if (dest) {
      CGImageDestinationAddImage(dest, image, NULL);
      CGImageDestinationFinalize(dest);
      CFRelease(dest);
    }

    NSString* base64 = [pngData base64EncodedStringWithOptions:0];
    NSDictionary* root = @{
      @"error": @NO,
      @"pngBase64": base64 ?: @"",
      @"width": @(CGImageGetWidth(image)),
      @"height": @(CGImageGetHeight(image))
    };
    NSData* data = [NSJSONSerialization dataWithJSONObject:root options:0 error:nil];
    if (data) {
      NSString* str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
      result = strdup(str.UTF8String);
    }
    dispatch_semaphore_signal(sem);
  }];
  } else {
    NSDictionary* errDict = @{
      @"error": @YES,
      @"domain": @"ScreenCaptureKit",
      @"code": @(-3),
      @"localizedDescription": @"Screenshot capture requires macOS 14.0 or newer"
    };
    NSData* errData = [NSJSONSerialization dataWithJSONObject:errDict options:0 error:nil];
    if (errData) {
      NSString* errStr = [[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding];
      result = strdup(errStr.UTF8String);
    }
    dispatch_semaphore_signal(sem);
  }

  const int64_t timeoutNsec = 10LL * NSEC_PER_SEC;
  dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, timeoutNsec));

  if (!result) {
    NSDictionary* errDict = @{
      @"error": @YES,
      @"domain": @"ScreenCaptureKit",
      @"code": @(-1),
      @"localizedDescription": @"Timed out waiting for screenshot capture"
    };
    NSData* errData = [NSJSONSerialization dataWithJSONObject:errDict options:0 error:nil];
    if (errData) {
      NSString* errStr = [[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding];
      result = strdup(errStr.UTF8String);
    }
  }

  return result;
}
