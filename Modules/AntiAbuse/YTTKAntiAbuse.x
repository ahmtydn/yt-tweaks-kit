#import "YTTKAntiAbuse.h"
#import "../../Core/YTTKModuleManager.h"
#import "../../Core/YTTKConstants.h"
#import "../../Core/YTTKLogger.h"
#import "../../Settings/YTTKSettings.h"
#import <objc/runtime.h>

static NSString *const kAntiAbuseHost = @"iosantiabuse-pa.googleapis.com";

// ─── Per-hook counters ──────────────────────────────────────────────────────

static NSUInteger _blockedNetworkCount = 0;
static NSUInteger _blockedIGDRefreshTokenAndCall = 0;
static NSUInteger _blockedIGDRefreshToken = 0;
static NSUInteger _blockedIGDRefreshTokenWithState = 0;
static NSUInteger _blockedIGDExecuteInit = 0;
static NSUInteger _blockedAttFetch = 0;
static NSUInteger _blockedAttRefresh = 0;
static NSUInteger _blockedAttExecuteChallenge = 0;
static NSUInteger _blockedAttInvalidate = 0;
static NSUInteger _blockedIOSGuardHandle = 0;

// ─── Hooks (must be defined before %init call) ──────────────────────────────

%group AntiAbuseHooks

// ── 1. NSURLSessionConfiguration: inject URL protocol into all sessions ─────

%hook NSURLSessionConfiguration

- (NSArray *)protocolClasses {
    NSMutableArray *protocols = [NSMutableArray arrayWithObject:[YTTKAntiAbuseURLProtocol class]];
    NSArray *orig = %orig;
    if (orig) [protocols addObjectsFromArray:orig];
    return protocols;
}

%end

// ── 2. IGDIntegrityTokenManager: stop integrity token refresh cycle ─────────

%hook IGDIntegrityTokenManager

- (void)refreshIntegrityTokenAndCall:(id)a0 onQueue:(id)a1 failFast:(BOOL)a2 seededRefreshState:(id)a3 {
    _blockedIGDRefreshTokenAndCall++;
    YTTKLog(@"[AntiAbuse][IGD] BLOCKED refreshIntegrityTokenAndCall: (count: %lu, failFast: %@)",
            (unsigned long)_blockedIGDRefreshTokenAndCall, a2 ? @"YES" : @"NO");
}

- (void)refreshIntegrityToken:(id)a0 completionHandler:(id)a1 {
    _blockedIGDRefreshToken++;
    YTTKLog(@"[AntiAbuse][IGD] BLOCKED refreshIntegrityToken: (count: %lu)", (unsigned long)_blockedIGDRefreshToken);
}

- (void)refreshIntegrityTokenWithRefreshState:(id)a0 refreshStartDate:(id)a1 completionHandler:(id)a2 {
    _blockedIGDRefreshTokenWithState++;
    YTTKLog(@"[AntiAbuse][IGD] BLOCKED refreshIntegrityTokenWithRefreshState: (count: %lu, startDate: %@)",
            (unsigned long)_blockedIGDRefreshTokenWithState, a1);
}

- (void)executeInitializeAndCall:(id)a0 onQueue:(id)a1 failFast:(BOOL)a2 {
    _blockedIGDExecuteInit++;
    YTTKLog(@"[AntiAbuse][IGD] BLOCKED executeInitializeAndCall: (count: %lu, failFast: %@)",
            (unsigned long)_blockedIGDExecuteInit, a2 ? @"YES" : @"NO");
}

%end

// ── 3. YTAttestationChallengeProvider: stop attestation challenge refresh ───

%hook YTAttestationChallengeProvider

- (void)fetchAttestationChallenge {
    _blockedAttFetch++;
    YTTKLog(@"[AntiAbuse][Attestation] BLOCKED fetchAttestationChallenge (count: %lu)", (unsigned long)_blockedAttFetch);
}

- (void)refreshAttestationWithFailedAttempts:(NSUInteger)a0 refreshCompletion:(id)a1 {
    _blockedAttRefresh++;
    YTTKLog(@"[AntiAbuse][Attestation] BLOCKED refreshAttestationWithFailedAttempts: %lu (count: %lu)",
            (unsigned long)a0, (unsigned long)_blockedAttRefresh);
}

- (void)executeChallengeForEngagementType:(id)a0 extraContentBindings:(id)a1 enforceValidChallenge:(BOOL)a2 withCompletion:(id)a3 onQueue:(id)a4 {
    _blockedAttExecuteChallenge++;
    YTTKLog(@"[AntiAbuse][Attestation] BLOCKED executeChallengeForEngagementType: %@ enforceValid: %@ (count: %lu)",
            a0, a2 ? @"YES" : @"NO", (unsigned long)_blockedAttExecuteChallenge);
}

- (void)invalidateAndRestartRefreshWithCompletion:(id)a0 {
    _blockedAttInvalidate++;
    YTTKLog(@"[AntiAbuse][Attestation] BLOCKED invalidateAndRestartRefreshWithCompletion: (count: %lu)",
            (unsigned long)_blockedAttInvalidate);
}

%end

// ── 4. YTIOSGuardSnapshotControllerImpl: bypass snapshot/challenge ──────────

%hook YTIOSGuardSnapshotControllerImpl

- (void)handleAttestationChallengeResponse:(id)a0 error:(id)a1 videoID:(id)a2 identityID:(id)a3 completionHandler:(id)a4 {
    _blockedIOSGuardHandle++;
    YTTKLog(@"[AntiAbuse][IOSGuard] BLOCKED handleAttestationChallengeResponse: (count: %lu, videoID: %@, error: %@, hasCompletion: %@)",
            (unsigned long)_blockedIOSGuardHandle, a2, a1, a4 ? @"YES" : @"NO");
    if (a4) {
        YTTKLog(@"[AntiAbuse][IOSGuard] Calling completion with nil (bypassing challenge)");
        ((void(^)(id))a4)(nil);
    }
}

%end

%end

// ─── URL Protocol (network-level fallback) ──────────────────────────────────

@implementation YTTKAntiAbuseURLProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    NSString *host = request.URL.host;
    if (host && [host isEqualToString:kAntiAbuseHost]) {
        _blockedNetworkCount++;
        YTTKLog(@"[AntiAbuse][Network] INTERCEPTED request #%lu — %@ %@",
                (unsigned long)_blockedNetworkCount, request.HTTPMethod ?: @"GET", request.URL.absoluteString);
        return YES;
    }
    return NO;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b {
    return [super requestIsCacheEquivalent:a toRequest:b];
}

- (void)startLoading {
    YTTKLog(@"[AntiAbuse][Network] BLOCKED request — returning empty 200 for %@", self.request.URL.host);
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL
                                                             statusCode:200
                                                            HTTPVersion:@"HTTP/1.1"
                                                           headerFields:@{
                                                               @"Content-Type": @"application/x-protobuf",
                                                               @"Content-Length": @"0"
                                                           }];
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    [self.client URLProtocol:self didLoadData:[NSData data]];
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)stopLoading {}

@end

// ─── Module Implementation ──────────────────────────────────────────────────

#define LOC_AA(x) [YTTKBundle() localizedStringForKey:x value:nil table:nil]

@implementation YTTKAntiAbuse

+ (NSString *)moduleIdentifier {
    return @"antiabuse";
}

+ (NSString *)moduleName {
    return LOC_AA(@"YTTK_ANTIABUSE_NAME");
}

+ (NSString *)moduleDescription {
    return LOC_AA(@"YTTK_ANTIABUSE_DESC");
}

+ (BOOL)isEnabled {
    return YTTKIsModuleEnabled([self moduleIdentifier]);
}

+ (BOOL)enabledByDefault {
    return YES;
}

+ (BOOL)requiresRestart {
    return YES;
}

+ (void)activate {
    YTTKLog(@"[AntiAbuse] ──────────────────────────────────────────────────");
    YTTKLog(@"[AntiAbuse] Module ACTIVATING...");
    YTTKLog(@"[AntiAbuse] Target host: %@", kAntiAbuseHost);

    // Register NSURLProtocol
    BOOL protocolRegistered = [NSURLProtocol registerClass:[YTTKAntiAbuseURLProtocol class]];
    if (protocolRegistered) {
        YTTKLog(@"[AntiAbuse] NSURLProtocol registered: YES — network-level blocking ACTIVE");
    } else {
        YTTKLog(@"[AntiAbuse] NSURLProtocol registered: FAILED — network-level blocking INACTIVE");
    }

    // Init hooks
    YTTKLog(@"[AntiAbuse] Initializing hooks...");

    BOOL igdExists = objc_getClass("IGDIntegrityTokenManager") != nil;
    BOOL attExists = objc_getClass("YTAttestationChallengeProvider") != nil;
    BOOL iosGuardExists = objc_getClass("YTIOSGuardSnapshotControllerImpl") != nil;

    YTTKLog(@"[AntiAbuse]   IGDIntegrityTokenManager:          %@", igdExists ? @"FOUND" : @"NOT FOUND — hook will be skipped by runtime");
    YTTKLog(@"[AntiAbuse]   YTAttestationChallengeProvider:     %@", attExists ? @"FOUND" : @"NOT FOUND — hook will be skipped by runtime");
    YTTKLog(@"[AntiAbuse]   YTIOSGuardSnapshotControllerImpl:   %@", iosGuardExists ? @"FOUND" : @"NOT FOUND — hook will be skipped by runtime");

    %init(AntiAbuseHooks);

    YTTKLog(@"[AntiAbuse] Hooks initialized successfully");
    YTTKLog(@"[AntiAbuse] Module ACTIVATED — all anti-abuse channels are being blocked");
    YTTKLog(@"[AntiAbuse] ──────────────────────────────────────────────────");
}

@end

// ─── Constructor ────────────────────────────────────────────────────────────

%ctor {
    YTTKLog(@"[AntiAbuse] Constructor called — registering module with YTTKModuleManager");
    [[YTTKModuleManager sharedManager] registerModule:[YTTKAntiAbuse class]];
    YTTKLog(@"[AntiAbuse] Module registered successfully");
}
