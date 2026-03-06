#import "YTTKAntiAbuse.h"
#import "../../Core/YTTKModuleManager.h"
#import "../../Core/YTTKConstants.h"
#import "../../Core/YTTKLogger.h"
#import "../../Settings/YTTKSettings.h"
#import <objc/runtime.h>

static NSString *const kAntiAbuseHost = @"iosantiabuse-pa.googleapis.com";
static NSUInteger _blockedCount = 0;

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
    YTTKLog(@"AntiAbuse: blocked IGDIntegrityTokenManager refreshIntegrityTokenAndCall:");
    // Don't call %orig — stop the refresh cycle entirely
}

- (void)refreshIntegrityToken:(id)a0 completionHandler:(id)a1 {
    YTTKLog(@"AntiAbuse: blocked IGDIntegrityTokenManager refreshIntegrityToken:");
}

- (void)refreshIntegrityTokenWithRefreshState:(id)a0 refreshStartDate:(id)a1 completionHandler:(id)a2 {
    YTTKLog(@"AntiAbuse: blocked IGDIntegrityTokenManager refreshIntegrityTokenWithRefreshState:");
}

- (void)executeInitializeAndCall:(id)a0 onQueue:(id)a1 failFast:(BOOL)a2 {
    YTTKLog(@"AntiAbuse: blocked IGDIntegrityTokenManager executeInitializeAndCall:");
}

%end

// ── 3. YTAttestationChallengeProvider: stop attestation challenge refresh ───

%hook YTAttestationChallengeProvider

- (void)fetchAttestationChallenge {
    YTTKLog(@"AntiAbuse: blocked YTAttestationChallengeProvider fetchAttestationChallenge");
}

- (void)refreshAttestationWithFailedAttempts:(NSUInteger)a0 refreshCompletion:(id)a1 {
    YTTKLog(@"AntiAbuse: blocked YTAttestationChallengeProvider refreshAttestationWithFailedAttempts:");
}

- (void)executeChallengeForEngagementType:(id)a0 extraContentBindings:(id)a1 enforceValidChallenge:(BOOL)a2 withCompletion:(id)a3 onQueue:(id)a4 {
    YTTKLog(@"AntiAbuse: blocked YTAttestationChallengeProvider executeChallengeForEngagementType:");
}

- (void)invalidateAndRestartRefreshWithCompletion:(id)a0 {
    YTTKLog(@"AntiAbuse: blocked YTAttestationChallengeProvider invalidateAndRestartRefreshWithCompletion:");
}

%end

// ── 4. YTIOSGuardSnapshotControllerImpl: bypass snapshot/challenge ──────────

%hook YTIOSGuardSnapshotControllerImpl

- (void)handleAttestationChallengeResponse:(id)a0 error:(id)a1 videoID:(id)a2 identityID:(id)a3 completionHandler:(id)a4 {
    YTTKLog(@"AntiAbuse: blocked YTIOSGuardSnapshotControllerImpl handleAttestationChallengeResponse:");
    // Call completion with nil to signal "no challenge needed"
    if (a4) {
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
        _blockedCount++;
        if (_blockedCount <= 3) {
            YTTKLog(@"AntiAbuse: blocking network request #%lu to %@", (unsigned long)_blockedCount, host);
        }
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
    YTTKLog(@"AntiAbuse module activated — hooking IGDIntegrityTokenManager, YTAttestationChallengeProvider, YTIOSGuardSnapshotControllerImpl");

    // Internal YouTube class hooks + NSURLProtocol fallback
    [NSURLProtocol registerClass:[YTTKAntiAbuseURLProtocol class]];
    %init(AntiAbuseHooks);
}

@end

// ─── Constructor ────────────────────────────────────────────────────────────

%ctor {
    [[YTTKModuleManager sharedManager] registerModule:[YTTKAntiAbuse class]];
}
