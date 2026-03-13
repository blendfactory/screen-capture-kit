#import <Foundation/Foundation.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>
#import <CoreGraphics/CoreGraphics.h>

#if __MAC_OS_X_VERSION_MIN_REQUIRED < 120300
#error "ScreenCaptureKit requires macOS 12.3 or newer"
#endif

static NSMutableDictionary<NSNumber*, SCContentFilter*>* _filterRegistry = nil;
static int64_t _nextFilterId = 1;

static void ensureFilterRegistry(void) {
  if (_filterRegistry == nil) {
    _filterRegistry = [NSMutableDictionary dictionary];
  }
}

/// Ensures Core Graphics is initialized. Required before SCContentFilter init in CLI apps.
/// Ref: https://developer.apple.com/forums/thread/743615
static void ensureCoreGraphicsInit(void) {
  (void)CGMainDisplayID();
}

/// Creates an SCContentFilter for the given window.
/// Returns a positive filter ID on success, 0 on error.
/// The filter is stored and must be released with release_content_filter.
int64_t create_content_filter_for_window(int64_t window_id) {
  ensureCoreGraphicsInit();
  ensureFilterRegistry();

  __block int64_t filterId = 0;
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);

  [SCShareableContent getShareableContentExcludingDesktopWindows:YES
                                             onScreenWindowsOnly:YES
                                                completionHandler:^(SCShareableContent* _Nullable content, NSError* _Nullable error) {
    if (error || !content) {
      dispatch_semaphore_signal(sem);
      return;
    }

    SCWindow* targetWindow = nil;
    for (SCWindow* w in content.windows) {
      if ((int64_t)w.windowID == window_id) {
        targetWindow = w;
        break;
      }
    }

    if (!targetWindow) {
      dispatch_semaphore_signal(sem);
      return;
    }

    SCContentFilter* filter = [[SCContentFilter alloc] initWithDesktopIndependentWindow:targetWindow];
    if (filter) {
      @synchronized (_filterRegistry) {
        filterId = _nextFilterId++;
        _filterRegistry[@(filterId)] = filter;
      }
    }
    dispatch_semaphore_signal(sem);
  }];

  const int64_t timeoutNsec = 5LL * NSEC_PER_SEC;
  dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, timeoutNsec));

  return filterId;
}

/// Releases a content filter created by create_content_filter_for_window.
void release_content_filter(int64_t filter_id) {
  if (filter_id <= 0 || _filterRegistry == nil) return;
  @synchronized (_filterRegistry) {
    [_filterRegistry removeObjectForKey:@(filter_id)];
  }
}
