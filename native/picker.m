#import "content_filter.h"
#import <ScreenCaptureKit/ScreenCaptureKit.h>
#import <Foundation/Foundation.h>
#include <string.h>

#if __MAC_OS_X_VERSION_MIN_REQUIRED < 120300
#error "ScreenCaptureKit requires macOS 12.3 or newer"
#endif

static int64_t _pickerResultFilterId = 0;
static int _pickerCancelled = 1;
static dispatch_semaphore_t _pickerSem = NULL;
static id _pickerObserver = nil;

API_AVAILABLE(macos(14.0))
@interface PickerObserver : NSObject <SCContentSharingPickerObserver>
@end

@implementation PickerObserver

- (void)contentSharingPicker:(SCContentSharingPicker *)picker didUpdateWithFilter:(SCContentFilter *)filter forStream:(SCStream *)stream {
  if (filter) {
    _pickerResultFilterId = register_content_filter(filter);
    _pickerCancelled = 0;
  }
  if (_pickerSem) dispatch_semaphore_signal(_pickerSem);
  if (picker && _pickerObserver) [(SCContentSharingPicker *)picker removeObserver:(id<SCContentSharingPickerObserver>)_pickerObserver];
  CFRunLoopStop(CFRunLoopGetMain());
}

- (void)contentSharingPicker:(SCContentSharingPicker *)picker didCancelForStream:(SCStream *)stream {
  _pickerCancelled = 1;
  _pickerResultFilterId = 0;
  if (_pickerSem) dispatch_semaphore_signal(_pickerSem);
  if (picker && _pickerObserver) [(SCContentSharingPicker *)picker removeObserver:(id<SCContentSharingPickerObserver>)_pickerObserver];
  CFRunLoopStop(CFRunLoopGetMain());
}

- (void)contentSharingPickerStartDidFailWithError:(NSError *)error {
  _pickerCancelled = 1;
  _pickerResultFilterId = 0;
  if (_pickerSem) dispatch_semaphore_signal(_pickerSem);
  CFRunLoopStop(CFRunLoopGetMain());
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

/// Presents the system content-sharing picker. Blocks until user selects or cancels.
/// allowed_modes_json: optional JSON array of mode names, e.g. ["singleDisplay","singleWindow"]. NULL or empty = all modes.
/// Returns malloc'd JSON. Success: {"cancelled":false,"filterId":N}. Cancel: {"cancelled":true}. Error: {"error":true,"domain","code","localizedDescription"}.
/// Caller must free with free(). Requires macOS 14.0+.
char* picker_present(const char* _Nullable allowed_modes_json) {
  if (!@available(macOS 14.0, *)) {
    NSDictionary* errDict = @{
      @"error": @YES,
      @"domain": @"ScreenCaptureKit",
      @"code": @(-3),
      @"localizedDescription": @"Content sharing picker requires macOS 14.0 or newer"
    };
    NSData* errData = [NSJSONSerialization dataWithJSONObject:errDict options:0 error:nil];
    if (errData) {
      NSString* errStr = [[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding];
      return strdup(errStr.UTF8String);
    }
    return NULL;
  }

  if (@available(macOS 14.0, *)) {
    _pickerResultFilterId = 0;
    _pickerCancelled = 1;
    _pickerSem = dispatch_semaphore_create(0);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-method-access"
    SCContentSharingPicker* picker = [SCContentSharingPicker shared];
    _pickerObserver = [[PickerObserver alloc] init];
    [picker addObserver:(id<SCContentSharingPickerObserver>)_pickerObserver];

    SCContentSharingPickerMode modes = picker_modes_from_json(allowed_modes_json);

    dispatch_async(dispatch_get_main_queue(), ^{
      if (modes != 0) {
        [picker presentUsing:modes];
      } else {
        [picker present];
      }
      CFRunLoopRun();
      dispatch_semaphore_signal(_pickerSem);
    });
#pragma clang diagnostic pop

    const int64_t timeoutNsec = 300LL * NSEC_PER_SEC;
    long waitResult = dispatch_semaphore_wait(
        _pickerSem, dispatch_time(DISPATCH_TIME_NOW, timeoutNsec));
    if (waitResult != 0) {
      _pickerCancelled = 1;
      if (picker && _pickerObserver) {
        [picker removeObserver:(id<SCContentSharingPickerObserver>)_pickerObserver];
      }
      NSDictionary* errDict = @{
        @"error": @YES,
        @"domain": @"ScreenCaptureKit",
        @"code": @(-1),
        @"localizedDescription": @"Content sharing picker timed out"
      };
      NSData* errData = [NSJSONSerialization dataWithJSONObject:errDict options:0 error:nil];
      if (errData) {
        NSString* errStr = [[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding];
        return strdup(errStr.UTF8String);
      }
      return NULL;
    }

    if (picker && _pickerObserver) {
      [picker removeObserver:(id<SCContentSharingPickerObserver>)_pickerObserver];
    }
    _pickerObserver = nil;

    if (_pickerCancelled) {
      NSDictionary* root = @{ @"cancelled": @YES };
      NSData* data = [NSJSONSerialization dataWithJSONObject:root options:0 error:nil];
      if (data) {
        NSString* str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return strdup(str.UTF8String);
      }
      return NULL;
    }

    NSDictionary* root = @{
      @"cancelled": @NO,
      @"filterId": @(_pickerResultFilterId)
    };
    NSData* data = [NSJSONSerialization dataWithJSONObject:root options:0 error:nil];
    if (data) {
      NSString* str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
      return strdup(str.UTF8String);
    }
  }
  return NULL;
}

/// Returns 1 if the system picker is active, 0 otherwise. Requires macOS 14.0+; returns 0 on older OS.
int picker_is_active(void) {
  if (@available(macOS 14.0, *)) {
    Class cls = NSClassFromString(@"SCContentSharingPicker");
    if (!cls) return 0;
    id picker = [cls performSelector:@selector(shared)];
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
    id picker = [cls performSelector:@selector(shared)];
    if (!picker) return 0;
    NSInvocation* inv = [NSInvocation invocationWithMethodSignature:
        [cls instanceMethodSignatureForSelector:@selector(maximumStreamCount)]];
    [inv setTarget:picker];
    [inv setSelector:@selector(maximumStreamCount)];
    [inv invoke];
    NSUInteger count = 0;
    [inv getReturnValue:&count];
    return (int)count;
  }
  return 0;
}
