#ifndef YTTKAntiAbuse_h
#define YTTKAntiAbuse_h

#import "../../Core/YTTKModule.h"

/**
 * @class YTTKAntiAbuse
 * @abstract Blocks YouTube's anti-abuse/integrity token system to prevent playback failures.
 *
 * Hooks into YouTube's internal classes:
 *   1. IGDIntegrityTokenManager         — stops integrity token refresh cycle
 *   2. YTAttestationChallengeProvider   — blocks attestation challenge fetch/refresh
 *                                         (including the 7-parameter executeChallenge: variant)
 *   3. YTIOSGuardSnapshotControllerImpl — bypasses IOSGuard challenge handling,
 *                                         constructPlaybackAttestationSnapshot, and
 *                                         reuseStoredIOSGuardChallenge
 *   4. SSOIOSGuardManagerImpl           — blocks the core IOSGuard engine (root trigger)
 *   5. YTGenericAttestationController   — blocks generic attestation execution path
 *   6. YTIIosPlayerConfig               — disables iosguardEnable feature flag at source
 *   7. YTIHamplayerConfig               — disables enableStreamProtectionStatus
 *   8. NSURLProtocol fallback           — blocks iosantiabuse-pa.googleapis.com at network level
 */
@interface YTTKAntiAbuse : NSObject <YTTKModule>
@end

@interface YTTKAntiAbuseURLProtocol : NSURLProtocol
@end

#endif /* YTTKAntiAbuse_h */
