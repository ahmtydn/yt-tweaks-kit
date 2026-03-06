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
static NSUInteger _blockedAttExecuteChallengeFullSig = 0;
static NSUInteger _blockedAttInvalidate = 0;
static NSUInteger _blockedIOSGuardHandle = 0;
static NSUInteger _blockedIOSGuardConstruct = 0;
static NSUInteger _blockedIOSGuardReuse = 0;
static NSUInteger _blockedSSOGenerate = 0;
static NSUInteger _blockedSSORunSnapshot = 0;
static NSUInteger _blockedGenericAttExec = 0;
static NSUInteger _blockedGenericAttLog = 0;

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

// 7-parameter variant — was missing before, causing this path to escape the hook
- (void)executeChallenge:(id)a0 withEngagementType:(id)a1 extraContentBindings:(id)a2 withIosguardData:(id)a3 withAccountID:(id)a4 withCompletion:(id)a5 onQueue:(id)a6 {
    _blockedAttExecuteChallengeFullSig++;
    YTTKLog(@"[AntiAbuse][Attestation] BLOCKED executeChallenge:withEngagementType:withIosguardData: (count: %lu)",
            (unsigned long)_blockedAttExecuteChallengeFullSig);
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
    YTTKLog(@"[AntiAbuse][IOSGuard] BLOCKED handleAttestationChallengeResponse: (count: %lu, videoID: %@, error: %@)",
            (unsigned long)_blockedIOSGuardHandle, a2, a1);
    if (a4) ((void(^)(id))a4)(nil);
}

// Called during playback to construct an attestation snapshot — was missing before
- (void)constructPlaybackAttestationSnapshotWithCPN:(id)cpn identityID:(id)identityID visitorData:(id)visitorData videoID:(id)videoID completionHandler:(id)completion {
    _blockedIOSGuardConstruct++;
    YTTKLog(@"[AntiAbuse][IOSGuard] BLOCKED constructPlaybackAttestationSnapshot (count: %lu, videoID: %@)",
            (unsigned long)_blockedIOSGuardConstruct, videoID);
    if (completion) ((void(^)(id))completion)(nil);
}

- (void)constructPlaybackAttestationSnapshotWithCPN:(id)cpn identityID:(id)identityID visitorData:(id)visitorData videoID:(id)videoID retry:(BOOL)retry completionHandler:(id)completion {
    _blockedIOSGuardConstruct++;
    YTTKLog(@"[AntiAbuse][IOSGuard] BLOCKED constructPlaybackAttestationSnapshot+retry (count: %lu, videoID: %@, retry: %@)",
            (unsigned long)_blockedIOSGuardConstruct, videoID, retry ? @"YES" : @"NO");
    if (completion) ((void(^)(id))completion)(nil);
}

// Tries to reuse a cached challenge; if no cache exists it triggers a fresh network call
- (void)reuseStoredIOSGuardChallengeForVideoID:(id)videoID completionHandler:(id)completion {
    _blockedIOSGuardReuse++;
    YTTKLog(@"[AntiAbuse][IOSGuard] BLOCKED reuseStoredIOSGuardChallenge (count: %lu, videoID: %@)",
            (unsigned long)_blockedIOSGuardReuse, videoID);
    if (completion) ((void(^)(id))completion)(nil);
}

%end

// ── 5. SSOIOSGuardManagerImpl: block the core IOSGuard engine ───────────────
// This is the root cause — it generates and executes the actual challenge
// that ultimately triggers the iosantiabuse-pa.googleapis.com network request.
// Without hooking this, all downstream hooks are too late.

%hook SSOIOSGuardManagerImpl

- (void)generateChallengeRequestWithCompletion:(id)completion {
    _blockedSSOGenerate++;
    YTTKLog(@"[AntiAbuse][SSOIOSGuard] BLOCKED generateChallengeRequestWithCompletion: (count: %lu)",
            (unsigned long)_blockedSSOGenerate);
    // Do not call completion — silently suppress
}

- (void)runAndSnapshotWithChallenge:(id)challenge setup:(id)setup completion:(id)completion {
    _blockedSSORunSnapshot++;
    YTTKLog(@"[AntiAbuse][SSOIOSGuard] BLOCKED runAndSnapshotWithChallenge: (count: %lu)",
            (unsigned long)_blockedSSORunSnapshot);
    if (completion) ((void(^)(id, id))completion)(nil, nil);
}

%end

// ── 6. YTGenericAttestationController: block generic attestation path ────────

%hook YTGenericAttestationController

- (void)executeChallenge:(id)a0 withIosguardData:(id)a1 clickTrackingParams:(id)a2 {
    _blockedGenericAttExec++;
    YTTKLog(@"[AntiAbuse][GenericAttestation] BLOCKED executeChallenge:withIosguardData: (count: %lu)",
            (unsigned long)_blockedGenericAttExec);
}

// Logging an unexecuted challenge can trigger a retry loop
- (void)logUnexecutedChallenge:(id)a0 clickTrackingParams:(id)a1 {
    _blockedGenericAttLog++;
    YTTKLog(@"[AntiAbuse][GenericAttestation] BLOCKED logUnexecutedChallenge: (count: %lu)",
            (unsigned long)_blockedGenericAttLog);
}

%end

// ── 7. YTIIosPlayerConfig: disable IOSGuard feature flag at the source ───────
// This tells YouTube's player config that IOSGuard is disabled entirely,
// preventing the entire challenge construction pipeline from being invoked.

%hook YTIIosPlayerConfig

- (BOOL)iosguardEnable {
    return NO;
}

- (BOOL)hasIosguardEnable {
    return NO;
}

- (BOOL)isIosguardAttestationEnabled {
    return NO;
}

%end

// ── 8. YTIHamplayerConfig: disable stream protection status ─────────────────
// Secondary path — disabling this prevents re-attestation triggered
// by the HAM (Headless Audio/Media) player layer.

%hook YTIHamplayerConfig

- (BOOL)enableStreamProtectionStatus {
    return NO;
}

- (BOOL)hasEnableStreamProtectionStatus {
    return NO;
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

    // Register NSURLProtocol (last-resort network fallback)
    BOOL protocolRegistered = [NSURLProtocol registerClass:[YTTKAntiAbuseURLProtocol class]];
    YTTKLog(@"[AntiAbuse] NSURLProtocol registered: %@", protocolRegistered ? @"YES" : @"FAILED");

    // Log class availability
    YTTKLog(@"[AntiAbuse] Checking hook targets...");
    struct { const char *name; } classes[] = {
        { "IGDIntegrityTokenManager" },
        { "YTAttestationChallengeProvider" },
        { "YTIOSGuardSnapshotControllerImpl" },
        { "SSOIOSGuardManagerImpl" },
        { "YTGenericAttestationController" },
        { "YTIIosPlayerConfig" },
        { "YTIHamplayerConfig" },
    };
    for (NSUInteger i = 0; i < sizeof(classes)/sizeof(classes[0]); i++) {
        BOOL found = objc_getClass(classes[i].name) != nil;
        YTTKLog(@"[AntiAbuse]   %-40s %@", classes[i].name, found ? @"FOUND" : @"NOT FOUND");
    }

    %init(AntiAbuseHooks);

    YTTKLog(@"[AntiAbuse] All hooks initialized — anti-abuse channels blocked");
    YTTKLog(@"[AntiAbuse] ──────────────────────────────────────────────────");
}

@end

// ─── Constructor ────────────────────────────────────────────────────────────

%ctor {
    YTTKLog(@"[AntiAbuse] Constructor called — registering module with YTTKModuleManager");
    [[YTTKModuleManager sharedManager] registerModule:[YTTKAntiAbuse class]];
    YTTKLog(@"[AntiAbuse] Module registered successfully");
}
