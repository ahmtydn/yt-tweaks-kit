#import "YTTKAntiAbuse.h"
#import "../../Core/YTTKModuleManager.h"
#import "../../Core/YTTKConstants.h"
#import "../../Core/YTTKLogger.h"
#import "../../Settings/YTTKSettings.h"
#import <os/lock.h>

// ─── Shared State (thread-safe) ─────────────────────────────────────────────

static os_unfair_lock _antiAbuseLock = OS_UNFAIR_LOCK_INIT;
static BOOL           _firstRequestSent = NO;
static BOOL           _firstRequestCompleted = NO;
static NSData        *_cachedResponseBody = nil;
static NSDictionary  *_cachedResponseHeaders = nil;
static NSInteger      _cachedStatusCode = 200;

static NSString *const kAntiAbuseHost = @"iosantiabuse-pa.googleapis.com";

// ─── Helper: Check if a URL is an anti-abuse request ────────────────────────

static BOOL YTTKIsAntiAbuseRequest(NSURLRequest *request) {
    NSString *host = request.URL.host;
    return (host && [host isEqualToString:kAntiAbuseHost]);
}

// ─── URL Protocol Implementation ────────────────────────────────────────────

@implementation YTTKAntiAbuseURLProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    if (!YTTKIsAntiAbuseRequest(request)) return NO;

    // Prevent infinite recursion: tag requests we've already touched
    if ([NSURLProtocol propertyForKey:@"YTTKAntiAbuseHandled" inRequest:request]) {
        return NO;
    }

    os_unfair_lock_lock(&_antiAbuseLock);
    BOOL firstSent = _firstRequestSent;
    if (!firstSent) {
        _firstRequestSent = YES;
    }
    os_unfair_lock_unlock(&_antiAbuseLock);

    if (!firstSent) {
        // First request — we intercept it ourselves to capture the response
        YTTKLog(@"AntiAbuse: capturing first request to %@", request.URL.host);
        return YES;
    }

    // Subsequent requests — intercept and replay cached response
    YTTKLog(@"AntiAbuse: intercepting subsequent request to %@", request.URL.host);
    return YES;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b {
    return [super requestIsCacheEquivalent:a toRequest:b];
}

- (void)startLoading {
    os_unfair_lock_lock(&_antiAbuseLock);
    BOOL hasCache = _firstRequestCompleted && _cachedResponseBody != nil;
    os_unfair_lock_unlock(&_antiAbuseLock);

    if (hasCache) {
        // We already have a cached response — replay it immediately
        [self replayWithCachedResponse];
    } else {
        // This is the first request — send it for real and cache the response
        [self performFirstRequest];
    }
}

- (void)stopLoading {
    // No-op: first request is fire-and-forget via a detached session task
}

// ─── First Request: Execute and Cache ───────────────────────────────────────

- (void)performFirstRequest {
    // Tag the request so our protocol doesn't intercept it again (infinite loop prevention)
    NSMutableURLRequest *taggedRequest = [self.request mutableCopy];
    [NSURLProtocol setProperty:@YES forKey:@"YTTKAntiAbuseHandled" inRequest:taggedRequest];

    // Use an ephemeral session so our custom protocolClasses hook doesn't apply
    NSURLSessionConfiguration *ephemeralConfig = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    ephemeralConfig.protocolClasses = @[]; // No custom protocols — direct network access
    NSURLSession *session = [NSURLSession sessionWithConfiguration:ephemeralConfig];

    NSURLSessionDataTask *task = [session dataTaskWithRequest:taggedRequest
                                           completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error || !data) {
            YTTKLog(@"AntiAbuse: first request failed: %@", error.localizedDescription);
            // Even on failure, provide a minimal valid response so the app doesn't hang
            [self replyWithEmptyProtobuf];
            os_unfair_lock_lock(&_antiAbuseLock);
            _firstRequestCompleted = YES;
            os_unfair_lock_unlock(&_antiAbuseLock);
            return;
        }

        // Cache the successful response
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        os_unfair_lock_lock(&_antiAbuseLock);
        _cachedResponseBody = [data copy];
        _cachedResponseHeaders = [httpResponse.allHeaderFields copy];
        _cachedStatusCode = httpResponse.statusCode;
        _firstRequestCompleted = YES;
        os_unfair_lock_unlock(&_antiAbuseLock);

        YTTKLog(@"AntiAbuse: first response cached (%lu bytes, HTTP %ld)",
                (unsigned long)data.length, (long)httpResponse.statusCode);

        // Deliver the real response to the original caller
        [self.client URLProtocol:self didReceiveResponse:httpResponse
                cacheStoragePolicy:NSURLCacheStorageNotAllowed];
        [self.client URLProtocol:self didLoadData:data];
        [self.client URLProtocolDidFinishLoading:self];
    }];
    [task resume];
}

// ─── Replay: Return Cached Response ─────────────────────────────────────────

- (void)replayWithCachedResponse {
    os_unfair_lock_lock(&_antiAbuseLock);
    NSData *body = [_cachedResponseBody copy];
    NSDictionary *headers = [_cachedResponseHeaders copy];
    NSInteger statusCode = _cachedStatusCode;
    os_unfair_lock_unlock(&_antiAbuseLock);

    NSHTTPURLResponse *fakeResponse = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL
                                                                 statusCode:statusCode
                                                                HTTPVersion:@"HTTP/1.1"
                                                               headerFields:headers];
    [self.client URLProtocol:self didReceiveResponse:fakeResponse
            cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    [self.client URLProtocol:self didLoadData:body];
    [self.client URLProtocolDidFinishLoading:self];
}

// ─── Fallback: Minimal Protobuf Response ────────────────────────────────────

- (void)replyWithEmptyProtobuf {
    NSHTTPURLResponse *fakeResponse = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL
                                                                 statusCode:200
                                                                HTTPVersion:@"HTTP/1.1"
                                                               headerFields:@{@"Content-Type": @"application/x-protobuf"}];
    [self.client URLProtocol:self didReceiveResponse:fakeResponse
            cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    // Minimal valid protobuf: empty message (zero bytes is valid)
    [self.client URLProtocol:self didLoadData:[NSData data]];
    [self.client URLProtocolDidFinishLoading:self];
}

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
    YTTKLog(@"AntiAbuse module activated — registering URL protocol and session hooks");

    // Register for NSURLConnection and shared NSURLSession
    [NSURLProtocol registerClass:[YTTKAntiAbuseURLProtocol class]];

    // Hook NSURLSessionConfiguration to inject into custom sessions
    %init(AntiAbuseHooks);
}

@end

// ─── Hooks ──────────────────────────────────────────────────────────────────

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

// ─── Constructor — Register this module ─────────────────────────────────────

%ctor {
    [[YTTKModuleManager sharedManager] registerModule:[YTTKAntiAbuse class]];
}
