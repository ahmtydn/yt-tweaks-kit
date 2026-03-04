#ifndef YTTKModule_h
#define YTTKModule_h

#import <Foundation/Foundation.h>

/**
 * @protocol YTTKModule
 * @abstract Base protocol that every tweak module must conform to.
 *
 * To create a new module:
 * 1. Create a new folder under Modules/ (e.g., Modules/MyFeature/)
 * 2. Implement this protocol in your module class
 * 3. In your %ctor, call [[YTTKModuleManager sharedManager] registerModule:[YourClass class]]
 * 4. Add your .x file to the Makefile's FILES list
 *
 * The ModuleManager will handle activation, settings UI toggle generation,
 * and preference storage automatically.
 */
@protocol YTTKModule <NSObject>

@required

/**
 * Unique reverse-domain style identifier for the module.
 * Used as the preference key suffix: "YTTKModule_{identifier}_enabled"
 * Example: @"helloworld"
 */
+ (NSString *)moduleIdentifier;

/**
 * Human-readable display name shown in the Settings UI.
 * Example: @"Hello World"
 */
+ (NSString *)moduleName;

/**
 * Short description of what the module does, shown below the toggle in Settings.
 * Return nil for no description.
 */
+ (NSString *)moduleDescription;

/**
 * Whether the module is currently enabled in user preferences.
 * Typically implemented by reading NSUserDefaults via YTTKIsModuleEnabled().
 */
+ (BOOL)isEnabled;

/**
 * Called when the module should activate its hooks/features.
 * This is called during %ctor if the module is enabled.
 * Place your %init(GroupName) calls here.
 */
+ (void)activate;

@optional

/**
 * Whether the module requires an app restart to take effect.
 * Defaults to NO if not implemented.
 */
+ (BOOL)requiresRestart;

/**
 * Whether the module is enabled by default when first installed.
 * Defaults to YES if not implemented.
 */
+ (BOOL)enabledByDefault;

@end

#endif /* YTTKModule_h */
