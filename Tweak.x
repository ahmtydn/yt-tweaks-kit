/**
 * YTTweaksKit — Main Tweak Entry Point
 *
 * This is the primary constructor that initializes the module system.
 * Individual modules register themselves via their own %ctor blocks.
 * This file's %ctor runs last (link order) and activates all enabled modules.
 */
#import "Core/YTTKModuleManager.h"
#import "Core/YTTKConstants.h"
#import "Core/YTTKConsoleLogStore.h"
#import "Core/YTTKLogger.h"

%ctor {
    [[YTTKConsoleLogStore sharedStore] startCaptureIfNeeded];
    YTTKLog(@"Initializing %@ v%@", YTTK_TWEAK_NAME, YTTK_TWEAK_VERSION);
    [[YTTKModuleManager sharedManager] activateEnabledModules];
    YTTKLog(@"Initialization complete");
}
