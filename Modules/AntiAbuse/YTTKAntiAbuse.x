#import "YTTKAntiAbuse.h"
#import "../../Core/YTTKModuleManager.h"
#import "../../Core/YTTKConstants.h"
#import "../../Core/YTTKLogger.h"
#import "../../Settings/YTTKSettings.h"

static NSString *const kAntiAbuseHost = @"iosantiabuse-pa.googleapis.com";
static NSUInteger _blockedCount = 0;

// ─── URL Protocol Implementation ────────────────────────────────────────────

@implementation YTTKAntiAbuseURLProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    NSString *host = request.URL.host;
    if (host && [host isEqualToString:kAntiAbuseHost]) {
        _blockedCount++;
        if (_blockedCount <= 3) {
            YTTKLog(@"AntiAbuse: blocking request #%lu to %@", (unsigned long)_blockedCount, host);
        } else if (_blockedCount == 4) {
            YTTKLog(@"AntiAbuse: suppressing further log messages (blocked %lu so far)", (unsigned long)_blockedCount);
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
    // Return an immediate empty 200 response — never hit the network
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

// ─── Hooks (must be defined before %init call) ──────────────────────────────

%group AntiAbuseHooks

%hook NSURLSessionConfiguration

- (NSArray *)protocolClasses {
    NSMutableArray *protocols = [NSMutableArray arrayWithObject:[YTTKAntiAbuseURLProtocol class]];
    NSArray *orig = %orig;
    if (orig) [protocols addObjectsFromArray:orig];
    return protocols;
}

%end

%end

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
    YTTKLog(@"AntiAbuse module activated — all requests to %@ will be blocked", kAntiAbuseHost);

    [NSURLProtocol registerClass:[YTTKAntiAbuseURLProtocol class]];
    %init(AntiAbuseHooks);
}

@end

// ─── Constructor — Register this module ─────────────────────────────────────

%ctor {
    [[YTTKModuleManager sharedManager] registerModule:[YTTKAntiAbuse class]];
}
