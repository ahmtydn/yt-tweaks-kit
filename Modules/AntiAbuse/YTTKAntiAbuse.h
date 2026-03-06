#ifndef YTTKAntiAbuse_h
#define YTTKAntiAbuse_h

#import "../../Core/YTTKModule.h"

/**
 * @class YTTKAntiAbuse
 * @abstract Blocks repeated iOS anti-abuse requests that cause playback failures.
 *
 * YouTube's iosantiabuse-pa.googleapis.com endpoint is continuously polled
 * in certain versions, causing videos to stop playing after ~40-60 seconds.
 *
 * Strategy:
 *   1. The first request passes through normally via a side-channel NSURLSession
 *   2. The response headers + body from that first request are cached (thread-safe)
 *   3. All subsequent requests are intercepted and receive the cached response
 *
 * This preserves VP9/AV1 codec support and 4K+ resolutions.
 */
@interface YTTKAntiAbuse : NSObject <YTTKModule>
@end

/**
 * NSURLProtocol subclass that intercepts iosantiabuse-pa.googleapis.com.
 * Caches the first valid response and replays it for subsequent requests.
 */
@interface YTTKAntiAbuseURLProtocol : NSURLProtocol
@end

#endif /* YTTKAntiAbuse_h */
