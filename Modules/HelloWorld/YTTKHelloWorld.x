#import "YTTKHelloWorld.h"
#import "../../Core/YTTKModuleManager.h"
#import "../../Core/YTTKConstants.h"
#import "../../Core/YTTKLogger.h"
#import "../../Settings/YTTKSettings.h"

// ─── Module Implementation ───────────────────────────────────────────────────

@implementation YTTKHelloWorld

+ (NSString *)moduleIdentifier {
    return @"helloworld";
}

+ (NSString *)moduleName {
    return @"Hello World";
}

+ (NSString *)moduleDescription {
    return @"Example module — logs a message to the console when activated.";
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
    YTTKLog(@"Hello World module activated! YTTweaksKit is working correctly.");
    // When you have hooks, you would call:
    // %init(HelloWorldHooks);
}

@end

// ─── Hooks (Example — uncomment and customize for real modules) ──────────────
//
// %group HelloWorldHooks
//
// %hook SomeYouTubeClass
//
// - (void)someMethod {
//     YTTKLog(@"HelloWorld: hooked someMethod");
//     %orig;
// }
//
// %end
// %end

// ─── Constructor — Register this module ──────────────────────────────────────

%ctor {
    [[YTTKModuleManager sharedManager] registerModule:[YTTKHelloWorld class]];
}
