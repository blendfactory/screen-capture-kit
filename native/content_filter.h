#import <Foundation/Foundation.h>

#if __MAC_OS_X_VERSION_MIN_REQUIRED < 120300
#error "ScreenCaptureKit requires macOS 12.3 or newer"
#endif

#import <ScreenCaptureKit/ScreenCaptureKit.h>

/// Returns the SCContentFilter for the given filter id, or nil if not found.
SCContentFilter* _Nullable get_content_filter(int64_t filter_id);

/// Registers an existing SCContentFilter (e.g. from picker) and returns a new filter id.
/// Caller retains ownership of filter; it is stored in the registry and released on release_content_filter.
int64_t register_content_filter(SCContentFilter* _Nonnull filter);
