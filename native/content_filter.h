#import <Foundation/Foundation.h>

#if __MAC_OS_X_VERSION_MIN_REQUIRED < 120300
#error "ScreenCaptureKit requires macOS 12.3 or newer"
#endif

#import <ScreenCaptureKit/ScreenCaptureKit.h>

/// Returns the SCContentFilter for the given filter id, or nil if not found.
SCContentFilter* _Nullable get_content_filter(int64_t filter_id);
