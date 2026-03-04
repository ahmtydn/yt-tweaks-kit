# YTTweaksKit

A **modular tweak toolkit** for the YouTube iOS app, built with [Theos](https://github.com/theos/theos).

Each feature lives in its own self-contained module. Modules register themselves automatically — no need to modify core files when adding new features.

## Architecture

```
yt-tweaks-kit/
├── Core/                    # Module protocol, manager, constants, logger
├── Settings/                # Preferences + auto-generated Settings UI
├── Modules/                 # Feature modules (each in its own folder)
│   └── HelloWorld/          # Example module template
├── Tweak.x                  # Main entry point — activates modules
├── Makefile                 # Theos build configuration
├── control                  # Debian package metadata
├── YTTweaksKit.plist        # Bundle filter (YouTube only)
└── layout/                  # Resource bundle (localization)
```

## Adding a New Module

1. Create a folder: `Modules/MyFeature/`
2. Create the header (`YTTKMyFeature.h`):

```objc
#import "../../Core/YTTKModule.h"

@interface YTTKMyFeature : NSObject <YTTKModule>
@end
```

3. Create the implementation (`YTTKMyFeature.x`):

```objc
#import "YTTKMyFeature.h"
#import "../../Core/YTTKModuleManager.h"
#import "../../Core/YTTKLogger.h"
#import "../../Settings/YTTKSettings.h"

@implementation YTTKMyFeature

+ (NSString *)moduleIdentifier { return @"myfeature"; }
+ (NSString *)moduleName       { return @"My Feature"; }
+ (NSString *)moduleDescription { return @"Does something cool."; }
+ (BOOL)isEnabled              { return YTTKIsModuleEnabled([self moduleIdentifier]); }
+ (BOOL)enabledByDefault       { return YES; }
+ (BOOL)requiresRestart        { return YES; }

+ (void)activate {
    %init(MyFeatureHooks);
}

@end

%group MyFeatureHooks

%hook SomeClass
- (void)someMethod {
    // Your hook logic here
    %orig;
}
%end

%end

%ctor {
    [[YTTKModuleManager sharedManager] registerModule:[YTTKMyFeature class]];
}
```

4. Add to `Makefile`:

```makefile
$(TWEAK_NAME)_FILES = \
    ...
    Modules/MyFeature/YTTKMyFeature.x \
    ...
```

That's it. The Settings UI toggle is generated automatically.

## Building

### Prerequisites

- [Theos](https://theos.dev/docs/installation)
- iOS 18.x SDK
- [YouTubeHeader](https://github.com/PoomSmart/YouTubeHeader) in `$THEOS/include/`
- [PSHeader](https://github.com/PoomSmart/PSHeader) in `$THEOS/include/`

### Build Commands

```bash
# Rootless (modern jailbreaks)
make clean package DEBUG=0 FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless

# Roothide
make clean package DEBUG=0 FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=roothide
```

## License

MIT
