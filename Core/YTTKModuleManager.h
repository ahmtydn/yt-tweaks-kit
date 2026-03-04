#ifndef YTTKModuleManager_h
#define YTTKModuleManager_h

#import <Foundation/Foundation.h>
#import "YTTKModule.h"

/**
 * @class YTTKModuleManager
 * @abstract Central registry and lifecycle manager for all tweak modules.
 *
 * Modules register themselves in their %ctor via registerModule:.
 * After all modules are registered, activateEnabledModules is called
 * from the main tweak constructor to initialize enabled modules.
 *
 * The Settings UI reads registeredModules to auto-generate toggle switches.
 */
@interface YTTKModuleManager : NSObject

/**
 * Singleton accessor.
 */
+ (instancetype)sharedManager;

/**
 * Register a module class conforming to YTTKModule.
 * Called from each module's %ctor.
 * @param moduleClass A Class that conforms to <YTTKModule>
 */
- (void)registerModule:(Class<YTTKModule>)moduleClass;

/**
 * Activate all registered modules whose isEnabled returns YES.
 * Called once from the main tweak %ctor after all modules have registered.
 */
- (void)activateEnabledModules;

/**
 * Returns an ordered array of all registered module classes.
 * Used by the Settings UI to generate toggle switches dynamically.
 */
- (NSArray<Class<YTTKModule>> *)registeredModules;

/**
 * Returns the number of currently active (enabled + activated) modules.
 */
- (NSUInteger)activeModuleCount;

@end

#endif /* YTTKModuleManager_h */
