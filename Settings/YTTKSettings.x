#import <PSHeader/Misc.h>
#import "YTTKSettings.h"
#import "../Core/YTTKConstants.h"
#import "../Core/YTTKLogger.h"

BOOL YTTKIsModuleEnabled(NSString *moduleIdentifier) {
    NSString *key = [NSString stringWithFormat:@"%@%@", YTTK_MODULE_PREFIX, moduleIdentifier];
    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

void YTTKSetModuleEnabled(NSString *moduleIdentifier, BOOL enabled) {
    NSString *key = [NSString stringWithFormat:@"%@%@", YTTK_MODULE_PREFIX, moduleIdentifier];
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:key];
}

NSBundle *YTTKBundle(void) {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *bundlePath = [[NSBundle mainBundle] pathForResource:YTTK_BUNDLE_NAME ofType:@"bundle"];
        bundle = [NSBundle bundleWithPath:bundlePath ?: PS_ROOT_PATH_NS(@"/Library/Application Support/YTTweaksKit.bundle")];
    });
    return bundle;
}
