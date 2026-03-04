#ifndef YTTKSettings_h
#define YTTKSettings_h

#import <Foundation/Foundation.h>

/**
 * Check if a module is enabled in user preferences.
 * @param moduleIdentifier The module's unique identifier string
 * @return YES if the module is enabled
 */
BOOL YTTKIsModuleEnabled(NSString *moduleIdentifier);

/**
 * Set a module's enabled state in user preferences.
 * @param moduleIdentifier The module's unique identifier string
 * @param enabled Whether the module should be enabled
 */
void YTTKSetModuleEnabled(NSString *moduleIdentifier, BOOL enabled);

/**
 * Returns the localization bundle for YTTweaksKit.
 * Searches mainBundle first, then falls back to /Library/Application Support/.
 */
NSBundle *YTTKBundle(void);

#endif /* YTTKSettings_h */
