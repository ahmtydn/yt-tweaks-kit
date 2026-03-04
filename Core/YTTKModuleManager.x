#import "YTTKModuleManager.h"
#import "YTTKConstants.h"
#import "YTTKLogger.h"

@implementation YTTKModuleManager {
    NSMutableArray<Class<YTTKModule>> *_modules;
    NSMutableSet<NSString *> *_activeModuleIdentifiers;
}

+ (instancetype)sharedManager {
    static YTTKModuleManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[YTTKModuleManager alloc] init];
    });
    return manager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _modules = [NSMutableArray array];
        _activeModuleIdentifiers = [NSMutableSet set];
    }
    return self;
}

- (void)registerModule:(Class<YTTKModule>)moduleClass {
    if (![moduleClass conformsToProtocol:@protocol(YTTKModule)]) {
        YTTKLog(@"Attempted to register non-conforming class: %@", NSStringFromClass(moduleClass));
        return;
    }

    // Prevent duplicate registration
    NSString *identifier = [moduleClass moduleIdentifier];
    for (Class<YTTKModule> existing in _modules) {
        if ([[existing moduleIdentifier] isEqualToString:identifier]) {
            YTTKLog(@"Module '%@' already registered, skipping duplicate", identifier);
            return;
        }
    }

    // Register default preference value
    BOOL enabledByDefault = YES;
    if ([moduleClass respondsToSelector:@selector(enabledByDefault)]) {
        enabledByDefault = [moduleClass enabledByDefault];
    }
    NSString *prefKey = [NSString stringWithFormat:@"%@%@", YTTK_MODULE_PREFIX, identifier];
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{prefKey: @(enabledByDefault)}];

    [_modules addObject:moduleClass];
    YTTKLog(@"Registered module: %@ (%@)", [moduleClass moduleName], identifier);
}

- (void)activateEnabledModules {
    YTTKLog(@"Activating enabled modules (%lu registered)...", (unsigned long)_modules.count);

    for (Class<YTTKModule> moduleClass in _modules) {
        if ([moduleClass isEnabled]) {
            @try {
                [moduleClass activate];
                [_activeModuleIdentifiers addObject:[moduleClass moduleIdentifier]];
                YTTKLog(@"Activated module: %@", [moduleClass moduleName]);
            } @catch (NSException *exception) {
                YTTKLog(@"Failed to activate module '%@': %@", [moduleClass moduleName], exception.reason);
            }
        } else {
            YTTKLog(@"Module '%@' is disabled, skipping", [moduleClass moduleName]);
        }
    }

    YTTKLog(@"Module activation complete. %lu/%lu active",
            (unsigned long)_activeModuleIdentifiers.count,
            (unsigned long)_modules.count);
}

- (NSArray<Class<YTTKModule>> *)registeredModules {
    return [_modules copy];
}

- (NSUInteger)activeModuleCount {
    return _activeModuleIdentifiers.count;
}

@end
