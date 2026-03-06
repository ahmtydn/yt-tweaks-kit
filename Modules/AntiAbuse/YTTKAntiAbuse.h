#ifndef YTTKAntiAbuse_h
#define YTTKAntiAbuse_h

#import "../../Core/YTTKModule.h"

/**
 * @class YTTKAntiAbuse
 * @abstract Blocks YouTube's anti-abuse/integrity token system to prevent playback failures.
 *
 * Hooks into YouTube's internal classes:
 *   - IGDIntegrityTokenManager: stops integrity token refresh cycle
 *   - YTAttestationChallengeProvider: blocks attestation challenge fetch/refresh
 *   - YTIOSGuardSnapshotControllerImpl: bypasses IOSGuard challenge handling
 *   - NSURLProtocol fallback: blocks iosantiabuse-pa.googleapis.com at network level
 */
@interface YTTKAntiAbuse : NSObject <YTTKModule>
@end

@interface YTTKAntiAbuseURLProtocol : NSURLProtocol
@end

#endif /* YTTKAntiAbuse_h */
