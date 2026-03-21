#import "content_filter.h"
#import <AppKit/AppKit.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>
#import <Foundation/Foundation.h>
#include <string.h>

#if __MAC_OS_X_VERSION_MIN_REQUIRED < 120300
#error "ScreenCaptureKit requires macOS 12.3 or newer"
#endif

static int64_t _pickerResultFilterId = 0;
static int _pickerCancelled = 1;
static id _pickerObserver = nil;
/// Set to YES by observer when the modal event loop should stop (replaces CFRunLoopStop).
static volatile BOOL _pickerEventLoopDone = NO;
static BOOL _pickerDidFinishLaunching = NO;

/// Async picker session: Dart must not block in FFI while main runs AppKit (deadlock).
static volatile int _pickerAsyncBusy = 0;
static volatile int _pickerAsyncReady = 0;
static char* _pickerAsyncResultJson = NULL;

API_AVAILABLE(macos(14.0))
@interface PickerObserver : NSObject <SCContentSharingPickerObserver>
@end

@implementation PickerObserver

- (void)contentSharingPicker:(SCContentSharingPicker *)picker didUpdateWithFilter:(SCContentFilter *)filter forStream:(SCStream *)stream {
  if (filter) {
    _pickerResultFilterId = register_content_filter(filter);
    _pickerCancelled = 0;
  }
  if (picker && _pickerObserver) {
    [(SCContentSharingPicker *)picker removeObserver:(id<SCContentSharingPickerObserver>)_pickerObserver];
    _pickerObserver = nil;
  }
  _pickerEventLoopDone = YES;
}

- (void)contentSharingPicker:(SCContentSharingPicker *)picker didCancelForStream:(SCStream *)stream {
  _pickerCancelled = 1;
  _pickerResultFilterId = 0;
  if (picker && _pickerObserver) {
    [(SCContentSharingPicker *)picker removeObserver:(id<SCContentSharingPickerObserver>)_pickerObserver];
    _pickerObserver = nil;
  }
  _pickerEventLoopDone = YES;
}

- (void)contentSharingPickerStartDidFailWithError:(NSError *)error {
  (void)error;
  _pickerCancelled = 1;
  _pickerResultFilterId = 0;
  SCContentSharingPicker* p = [SCContentSharingPicker sharedPicker];
  if (p && _pickerObserver) {
    [p removeObserver:(id<SCContentSharingPickerObserver>)_pickerObserver];
    _pickerObserver = nil;
  }
  _pickerEventLoopDone = YES;
}

@end

/// Build SCContentSharingPickerMode from JSON array of mode names.
/// e.g. ["singleDisplay", "singleWindow"] -> option set. Returns 0 if invalid or empty.
static SCContentSharingPickerMode picker_modes_from_json(const char* _Nullable modes_json) API_AVAILABLE(macos(14.0)) {
  if (!modes_json || modes_json[0] == '\0') return 0;
  NSData* data = [NSData dataWithBytes:modes_json length:strlen(modes_json)];
  NSError* err = nil;
  id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
  if (err || ![parsed isKindOfClass:[NSArray class]]) return 0;
  NSArray* arr = (NSArray*)parsed;
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

/// Builds malloc'd JSON for the current picker outcome (same schema as legacy picker_present).
static char* picker_make_result_json(void) {
  if (_pickerCancelled) {
    NSDictionary* root = @{@"cancelled" : @YES};
    NSData* data = [NSJSONSerialization dataWithJSONObject:root options:0 error:nil];
    if (data) {
      NSString* str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
      return strdup(str.UTF8String);
    }
    return NULL;
  }
  NSDictionary* root = @{
    @"cancelled" : @NO,
    @"filterId" : @(_pickerResultFilterId),
  };
  NSData* data = [NSJSONSerialization dataWithJSONObject:root options:0 error:nil];
  if (data) {
    NSString* str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return strdup(str.UTF8String);
  }
  return NULL;
}

/// Starts the content-sharing picker. The modal session and `nextEventMatchingMask` run on the
/// **AppKit main thread** (`dispatch_sync` when the caller is not already on that thread).
/// Returns 0 on success, -1 if a session is already in progress.
/// Blocks until the user dismisses the picker (or timeout). Requires macOS 14.0+ for the real picker.
int picker_start(const char* _Nullable allowed_modes_json) {
  if (@available(macOS 14.0, *)) {
    if (_pickerAsyncBusy) {
      return -1;
    }
    _pickerAsyncBusy = 1;
    _pickerAsyncReady = 0;
    if (_pickerAsyncResultJson != NULL) {
      free(_pickerAsyncResultJson);
      _pickerAsyncResultJson = NULL;
    }

    _pickerResultFilterId = 0;
    _pickerCancelled = 1;
    _pickerEventLoopDone = NO;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-method-access"
    SCContentSharingPicker* picker = [SCContentSharingPicker sharedPicker];
    _pickerObserver = [[PickerObserver alloc] init];
    [picker addObserver:(id<SCContentSharingPickerObserver>)_pickerObserver];

    SCContentSharingPickerMode modes = picker_modes_from_json(allowed_modes_json);
    SCContentSharingPickerConfiguration* cfg =
        [[SCContentSharingPickerConfiguration alloc] init];
    cfg.allowedPickerModes = modes;
    picker.defaultConfiguration = cfg;

    void (^runPickerSession)(void) = ^{
      NSApplication* app = [NSApplication sharedApplication];
      if ([app activationPolicy] != NSApplicationActivationPolicyRegular) {
        BOOL regularOk = [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        if (!regularOk) {
          (void)[app setActivationPolicy:NSApplicationActivationPolicyAccessory];
        }
      }
      if (!_pickerDidFinishLaunching) {
        [NSApp finishLaunching];
        _pickerDidFinishLaunching = YES;
      }
      [app activateIgnoringOtherApps:YES];

      picker.maximumStreamCount = @1;
      picker.active = YES;
      [picker present];

      NSDate* deadline = [NSDate dateWithTimeIntervalSinceNow:300];
      while (!_pickerEventLoopDone) {
        if ([[NSDate date] compare:deadline] == NSOrderedDescending) {
          _pickerCancelled = 1;
          break;
        }
        @autoreleasepool {
          NSDate* until = [NSDate dateWithTimeIntervalSinceNow:0.25];
          NSEvent* event = [NSApp nextEventMatchingMask:NSEventMaskAny
                                              untilDate:until
                                                 inMode:NSDefaultRunLoopMode
                                                dequeue:YES];
          if (event) {
            [NSApp sendEvent:event];
          }
        }
      }
    };

    void (^sessionAndCleanup)(void) = ^{
      runPickerSession();
      if (_pickerObserver != nil) {
        [picker removeObserver:(id<SCContentSharingPickerObserver>)_pickerObserver];
        _pickerObserver = nil;
      }
    };

    if ([NSThread isMainThread]) {
      sessionAndCleanup();
    } else {
      dispatch_sync(dispatch_get_main_queue(), sessionAndCleanup);
    }

    char* json = picker_make_result_json();
    _pickerAsyncResultJson = json;
    __sync_synchronize();
    _pickerAsyncReady = 1;
#pragma clang diagnostic pop
    return 0;
  }
  if (_pickerAsyncBusy) {
    return -1;
  }
  _pickerAsyncBusy = 1;
  NSDictionary* errDict = @{
    @"error" : @YES,
    @"domain" : @"ScreenCaptureKit",
    @"code" : @(-3),
    @"localizedDescription" : @"Content sharing picker requires macOS 14.0 or newer"
  };
  NSData* errData = [NSJSONSerialization dataWithJSONObject:errDict options:0 error:nil];
  if (errData) {
    NSString* errStr = [[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding];
    _pickerAsyncResultJson = strdup(errStr.UTF8String);
  } else {
    _pickerAsyncResultJson = NULL;
  }
  __sync_synchronize();
  _pickerAsyncReady = 1;
  return 0;
}

/// Returns malloc'd result JSON when ready, or NULL if still pending. Caller must free().
char* picker_poll(void) {
  if (!_pickerAsyncReady) {
    return NULL;
  }
  char* out = _pickerAsyncResultJson;
  _pickerAsyncResultJson = NULL;
  _pickerAsyncReady = 0;
  _pickerAsyncBusy = 0;
  return out;
}

/// Returns 1 if the system picker is active, 0 otherwise. Requires macOS 14.0+; returns 0 on older OS.
int picker_is_active(void) {
  if (@available(macOS 14.0, *)) {
    Class cls = NSClassFromString(@"SCContentSharingPicker");
    if (!cls) return 0;
    id picker = [cls performSelector:@selector(sharedPicker)];
    if (!picker) return 0;
    NSNumber* active = [picker performSelector:@selector(isActive)];
    return active.boolValue ? 1 : 0;
  }
  return 0;
}

/// Returns the maximum stream count for the picker. Requires macOS 14.0+; returns 0 on older OS.
int picker_maximum_stream_count(void) {
  if (@available(macOS 14.0, *)) {
    Class cls = NSClassFromString(@"SCContentSharingPicker");
    if (!cls) return 0;
    id picker = [cls performSelector:@selector(sharedPicker)];
    if (!picker) return 0;
    NSInvocation* inv = [NSInvocation invocationWithMethodSignature:
        [picker methodSignatureForSelector:@selector(maximumStreamCount)]];
    [inv setTarget:picker];
    [inv setSelector:@selector(maximumStreamCount)];
    [inv invoke];
    NSUInteger count = 0;
    [inv getReturnValue:&count];
    return (int)count;
  }
  return 0;
}
