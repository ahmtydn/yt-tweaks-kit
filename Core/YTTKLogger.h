#ifndef YTTKLogger_h
#define YTTKLogger_h

/**
 * YTTweaksKit Logger
 * Consistent logging with tweak prefix for easy Console filtering.
 *
 * Usage:
 *   YTTKLog(@"Module loaded");
 *   YTTKLog(@"Value: %d", someInt);
 *
 * Output:
 *   [YTTweaksKit] Module loaded
 *   [YTTweaksKit] Value: 42
 */

#ifdef DEBUG
    #define YTTKLog(fmt, ...) NSLog(@"[YTTweaksKit] " fmt, ##__VA_ARGS__)
#else
    #define YTTKLog(fmt, ...) NSLog(@"[YTTweaksKit] " fmt, ##__VA_ARGS__)
#endif

// Silent log — only in DEBUG builds
#ifdef DEBUG
    #define YTTKDebugLog(fmt, ...) NSLog(@"[YTTweaksKit:DEBUG] " fmt, ##__VA_ARGS__)
#else
    #define YTTKDebugLog(fmt, ...)
#endif

#endif /* YTTKLogger_h */
