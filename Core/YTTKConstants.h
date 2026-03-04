#ifndef YTTKConstants_h
#define YTTKConstants_h

/**
 * YTTweaksKit Constants
 * Central location for all shared constants, keys, and macros.
 */

// ─── Tweak Identity ──────────────────────────────────────────────────────────

#define YTTK_TWEAK_NAME     @"YTTweaksKit"
#define YTTK_TWEAK_VERSION  @"1.0.0"
#define YTTK_BUNDLE_NAME    @"YTTweaksKit"
#define YTTK_BUNDLE_ID      @"dev.ahmtydn.yttweakskit"

// ─── Settings Section ────────────────────────────────────────────────────────

// Four-char code used as the settings category identifier: 'yttk' = 0x7974746B
static const NSInteger YTTKSettingsSection = 'yttk';

// ─── Preference Key Patterns ─────────────────────────────────────────────────

// Module enable/disable keys follow this format:
// "YTTKModule_{moduleIdentifier}_enabled"
#define YTTK_MODULE_PREFIX @"YTTKModule_"

// ─── Build Info ──────────────────────────────────────────────────────────────

#define YTTK_MIN_IOS @"15.0"

#endif /* YTTKConstants_h */
