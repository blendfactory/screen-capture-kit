#import "content_filter.h"
#import <CoreGraphics/CoreGraphics.h>
#include <string.h>

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

/// Creates an SCContentFilter for the given display (entire display capture).
/// excludingApplications and exceptingWindows are empty for full display capture.
/// Returns a positive filter ID on success, 0 on error.
int64_t create_content_filter_for_display(int64_t display_id) {
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

    SCDisplay* targetDisplay = nil;
    for (SCDisplay* d in content.displays) {
      if ((int64_t)d.displayID == display_id) {
        targetDisplay = d;
        break;
      }
    }

    if (!targetDisplay) {
      dispatch_semaphore_signal(sem);
      return;
    }

    SCContentFilter* filter = [[SCContentFilter alloc] initWithDisplay:targetDisplay
                                                   excludingApplications:@[]
                                                     exceptingWindows:@[]];
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

/// Creates an SCContentFilter for the given display excluding specific windows.
/// window_ids_json: JSON array of window IDs, e.g. "[123, 456]".
/// Returns a positive filter ID on success, 0 on error.
int64_t create_content_filter_for_display_excluding_windows(int64_t display_id,
                                                             const char* _Nullable window_ids_json) {
  ensureCoreGraphicsInit();
  ensureFilterRegistry();
  if (!window_ids_json || window_ids_json[0] == '\0') {
    return create_content_filter_for_display(display_id);
  }

  NSData* jsonData = [NSData dataWithBytes:window_ids_json length:strlen(window_ids_json)];
  NSError* jsonError = nil;
  id parsed = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&jsonError];
  if (jsonError || ![parsed isKindOfClass:[NSArray class]]) {
    return 0;
  }
  NSArray* idArray = (NSArray*)parsed;
  NSMutableSet<NSNumber*>* excludeIds = [NSMutableSet setWithCapacity:idArray.count];
  for (id obj in idArray) {
    if ([obj isKindOfClass:[NSNumber class]]) {
      [excludeIds addObject:(NSNumber*)obj];
    }
  }
  if (excludeIds.count == 0) {
    return create_content_filter_for_display(display_id);
  }

  __block int64_t filterId = 0;
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);

  [SCShareableContent getShareableContentExcludingDesktopWindows:YES
                                             onScreenWindowsOnly:YES
                                                completionHandler:^(SCShareableContent* _Nullable content, NSError* _Nullable error) {
    if (error || !content) {
      dispatch_semaphore_signal(sem);
      return;
    }

    SCDisplay* targetDisplay = nil;
    for (SCDisplay* d in content.displays) {
      if ((int64_t)d.displayID == display_id) {
        targetDisplay = d;
        break;
      }
    }

    if (!targetDisplay) {
      dispatch_semaphore_signal(sem);
      return;
    }

    NSMutableArray<SCWindow*>* windowsToExclude = [NSMutableArray array];
    for (SCWindow* w in content.windows) {
      if ([excludeIds containsObject:@((int64_t)w.windowID)]) {
        [windowsToExclude addObject:w];
      }
    }

    SCContentFilter* filter = [[SCContentFilter alloc] initWithDisplay:targetDisplay
                                                     excludingWindows:windowsToExclude];
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

/// Returns the SCContentFilter for the given filter id, or nil if not found.
SCContentFilter* get_content_filter(int64_t filter_id) {
  if (filter_id <= 0 || _filterRegistry == nil) {
    return nil;
  }
  return _filterRegistry[@(filter_id)];
}

/// Releases a content filter created by create_content_filter_for_window.
void release_content_filter(int64_t filter_id) {
  if (filter_id <= 0 || _filterRegistry == nil) return;
  @synchronized (_filterRegistry) {
    [_filterRegistry removeObjectForKey:@(filter_id)];
  }
}
