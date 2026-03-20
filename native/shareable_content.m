#import <Foundation/Foundation.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>
#import <CoreGraphics/CoreGraphics.h>
#include <string.h>

#if __MAC_OS_X_VERSION_MIN_REQUIRED < 120300
#error "ScreenCaptureKit requires macOS 12.3 or newer"
#endif

/// C-compatible function callable from Dart FFI.
/// Returns a malloc'd JSON string. Caller must free with free().
/// Returns NULL on error.
char* get_shareable_content_json(int exclude_desktop_windows, int on_screen_windows_only) {
  __block char* result = NULL;
  // ARC manages dispatch_semaphore_t lifecycle; no manual dispatch_release needed.
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);

  [SCShareableContent getShareableContentExcludingDesktopWindows:(BOOL)exclude_desktop_windows
                                             onScreenWindowsOnly:(BOOL)on_screen_windows_only
                                                completionHandler:^(SCShareableContent* _Nullable content, NSError* _Nullable error) {
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

      if (!content) {
        dispatch_semaphore_signal(sem);
        return;
      }

      NSMutableArray* displaysJson = [NSMutableArray array];
      for (SCDisplay* d in content.displays) {
        double refreshRate = 0;
        CGDisplayModeRef mode = CGDisplayCopyDisplayMode(d.displayID);
        if (mode) {
          refreshRate = CGDisplayModeGetRefreshRate(mode);
          CGDisplayModeRelease(mode);
        }
        [displaysJson addObject:@{
          @"displayId": @(d.displayID),
          @"width": @((int)d.width),
          @"height": @((int)d.height),
          @"refreshRate": @(refreshRate)
        }];
      }

      NSMutableArray* appsJson = [NSMutableArray array];
      NSMutableDictionary* appByPid = [NSMutableDictionary dictionary];
      for (SCRunningApplication* app in content.applications) {
        NSDictionary* appDict = @{
          @"bundleIdentifier": app.bundleIdentifier ?: @"",
          @"applicationName": app.applicationName ?: @"",
          @"processId": @(app.processID)
        };
        [appsJson addObject:appDict];
        appByPid[@(app.processID)] = appDict;
      }

      NSMutableArray* windowsJson = [NSMutableArray array];
      for (SCWindow* w in content.windows) {
        SCRunningApplication* app = w.owningApplication;
        NSDictionary* appDict = app ? @{
          @"bundleIdentifier": app.bundleIdentifier ?: @"",
          @"applicationName": app.applicationName ?: @"",
          @"processId": @(app.processID)
        } : @{
          @"bundleIdentifier": @"",
          @"applicationName": @"",
          @"processId": @0
        };

        CGRect frame = w.frame;
        NSDictionary* frameDict = @{
          @"x": @(frame.origin.x),
          @"y": @(frame.origin.y),
          @"width": @(frame.size.width),
          @"height": @(frame.size.height)
        };

        NSMutableDictionary* winDict = [NSMutableDictionary dictionaryWithDictionary:@{
          @"windowId": @(w.windowID),
          @"frame": frameDict,
          @"owningApplication": appDict
        }];
        if (w.title.length > 0) {
          winDict[@"title"] = w.title;
        }
        [windowsJson addObject:winDict];
      }

      NSDictionary* root = @{
        @"displays": displaysJson,
        @"applications": appsJson,
        @"windows": windowsJson
      };

      NSError* jsonError = nil;
      NSData* data = [NSJSONSerialization dataWithJSONObject:root options:0 error:&jsonError];
      if (data && !jsonError) {
        NSString* str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        result = strdup(str.UTF8String);
      }
      dispatch_semaphore_signal(sem);
    }];

  const int64_t timeoutNsec = 5LL * NSEC_PER_SEC;
  const dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, timeoutNsec);
  const long waitResult = dispatch_semaphore_wait(sem, timeout);
  if (waitResult != 0) {
    NSDictionary* errDict = @{
      @"error": @YES,
      @"domain": @"ScreenCaptureKit",
      @"code": @(-1),
      @"localizedDescription": @"Timed out waiting for SCShareableContent completion"
    };
    NSData* errData = [NSJSONSerialization dataWithJSONObject:errDict options:0 error:nil];
    if (errData) {
      NSString* errStr = [[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding];
      result = strdup(errStr.UTF8String);
    }
  }
  return result;
}
