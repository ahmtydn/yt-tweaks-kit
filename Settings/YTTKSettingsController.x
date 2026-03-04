#import <PSHeader/Misc.h>
#import <UIKit/UIKit.h>
#import <YouTubeHeader/YTSettingsGroupData.h>
#import <YouTubeHeader/YTSettingsSectionItem.h>
#import <YouTubeHeader/YTSettingsSectionItemManager.h>
#import <YouTubeHeader/YTSettingsViewController.h>
#import "../Core/YTTKConsoleLogStore.h"
#import "../Core/YTTKConstants.h"
#import "../Core/YTTKLogger.h"
#import "../Core/YTTKModule.h"
#import "../Core/YTTKModuleManager.h"
#import "YTTKSettings.h"

#define LOC(x) [YTTKBundle() localizedStringForKey:x value:nil table:nil]

// ─── Category Declaration ────────────────────────────────────────────────────

@interface YTSettingsSectionItemManager (YTTweaksKit)
- (void)updateYTTKSectionWithEntry:(id)entry;
- (void)presentYTTKLogsFromController:(UIViewController *)viewController;
@end

// ─── Hook: Insert our section into the settings category list ────────────────

%hook YTSettingsGroupData

- (NSArray<NSNumber *> *)orderedCategories {
    if (self.type != 1 ||
        class_getClassMethod(objc_getClass("YTSettingsGroupData"), @selector(tweaks)))
        return %orig;

    NSMutableArray *mutableCategories = %orig.mutableCopy;
    [mutableCategories insertObject:@(YTTKSettingsSection) atIndex:0];
    return mutableCategories.copy;
}

%end

// ─── Hook: Define the ordering of our section ───────────────────────────────

%hook YTAppSettingsPresentationData

+ (NSArray<NSNumber *> *)settingsCategoryOrder {
    NSArray<NSNumber *> *order = %orig;
    NSUInteger insertIndex = [order indexOfObject:@(1)];
    if (insertIndex != NSNotFound) {
        NSMutableArray<NSNumber *> *mutableOrder = [order mutableCopy];
        [mutableOrder insertObject:@(YTTKSettingsSection) atIndex:insertIndex + 1];
        order = mutableOrder.copy;
    }
    return order;
}

%end

// ─── Hook: Build the settings UI dynamically from registered modules ────────

%hook YTSettingsSectionItemManager

%new(v@:@)
- (void)updateYTTKSectionWithEntry:(id)entry {
    NSMutableArray<YTSettingsSectionItem *> *sectionItems = [NSMutableArray array];
    Class YTSettingsSectionItemClass = %c(YTSettingsSectionItem);
    YTSettingsViewController *settingsViewController = [self valueForKey:@"_settingsViewControllerDelegate"];

    // ── Version Header ──────────────────────────────────────────────────

    NSString *versionString = [NSString stringWithFormat:@"%@ v%@", YTTK_TWEAK_NAME, YTTK_TWEAK_VERSION];
    YTSettingsSectionItem *versionItem = [YTSettingsSectionItemClass itemWithTitle:versionString
        titleDescription:LOC(@"YTTK_HEADER_DESC")
        accessibilityIdentifier:nil
        detailTextBlock:nil
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            return NO;
        }];
    [sectionItems addObject:versionItem];

    // ── Dynamic Module Toggles ──────────────────────────────────────────

    NSArray<Class<YTTKModule>> *modules = [[YTTKModuleManager sharedManager] registeredModules];

    for (Class<YTTKModule> moduleClass in modules) {
        NSString *moduleId = [moduleClass moduleIdentifier];
        NSString *moduleName = [moduleClass moduleName];
        NSString *moduleDesc = [moduleClass moduleDescription];

        // Append restart notice if module requires it
        if ([moduleClass respondsToSelector:@selector(requiresRestart)] && [moduleClass requiresRestart]) {
            NSString *restartNotice = LOC(@"YTTK_RESTART_REQUIRED");
            if (moduleDesc.length > 0) {
                moduleDesc = [NSString stringWithFormat:@"%@ %@", moduleDesc, restartNotice];
            } else {
                moduleDesc = restartNotice;
            }
        }

        YTSettingsSectionItem *toggle = [YTSettingsSectionItemClass switchItemWithTitle:moduleName
            titleDescription:moduleDesc
            accessibilityIdentifier:nil
            switchOn:YTTKIsModuleEnabled(moduleId)
            switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {
                YTTKSetModuleEnabled(moduleId, enabled);
                return YES;
            }
            settingItemId:0];
        [sectionItems addObject:toggle];
    }

    // ── Console Log Capture ────────────────────────────────────────────

    YTSettingsSectionItem *logCaptureSwitch = [YTSettingsSectionItemClass switchItemWithTitle:LOC(@"YTTK_LOG_CAPTURE_TITLE")
        titleDescription:LOC(@"YTTK_LOG_CAPTURE_DESC")
        accessibilityIdentifier:nil
        switchOn:[[YTTKConsoleLogStore sharedStore] isCaptureEnabled]
        switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {
            [[YTTKConsoleLogStore sharedStore] setCaptureEnabled:enabled];
            if (enabled) {
                [[YTTKConsoleLogStore sharedStore] startCaptureIfNeeded];
            } else {
                [[YTTKConsoleLogStore sharedStore] stopCaptureIfNeeded];
            }
            return YES;
        }
        settingItemId:0];
    [sectionItems addObject:logCaptureSwitch];

    YTSettingsSectionItem *showLogsItem = [YTSettingsSectionItemClass itemWithTitle:LOC(@"YTTK_VIEW_LOGS_TITLE")
        titleDescription:LOC(@"YTTK_VIEW_LOGS_DESC")
        accessibilityIdentifier:nil
        detailTextBlock:nil
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            [self presentYTTKLogsFromController:settingsViewController];
            return NO;
        }];
    [sectionItems addObject:showLogsItem];

    // ── Apply to Settings View ──────────────────────────────────────────

    if ([settingsViewController respondsToSelector:@selector(setSectionItems:forCategory:title:icon:titleDescription:headerHidden:)]) {
        YTIIcon *icon = [%c(YTIIcon) new];
        icon.iconType = YT_SETTINGS;
        [settingsViewController setSectionItems:sectionItems
                                    forCategory:YTTKSettingsSection
                                          title:YTTK_TWEAK_NAME
                                           icon:icon
                               titleDescription:nil
                                   headerHidden:NO];
    } else {
        [settingsViewController setSectionItems:sectionItems
                                    forCategory:YTTKSettingsSection
                                          title:YTTK_TWEAK_NAME
                               titleDescription:nil
                                   headerHidden:NO];
    }
}

%new(v@:@)
- (void)presentYTTKLogsFromController:(UIViewController *)viewController {
    NSString *logs = [[YTTKConsoleLogStore sharedStore] readLogTextForDisplay];
    if (logs.length == 0) {
        logs = LOC(@"YTTK_NO_LOGS");
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:LOC(@"YTTK_VIEW_LOGS_TITLE")
                                                                   message:logs
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *copyAction = [UIAlertAction actionWithTitle:LOC(@"YTTK_COPY_LOGS")
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(__unused UIAlertAction *action) {
        [UIPasteboard generalPasteboard].string = logs;
    }];

    UIAlertAction *closeAction = [UIAlertAction actionWithTitle:LOC(@"YTTK_CLOSE")
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [alert addAction:copyAction];
    [alert addAction:closeAction];

    UIViewController *presenter = viewController;
    while (presenter.presentedViewController) {
        presenter = presenter.presentedViewController;
    }

    [presenter presentViewController:alert animated:YES completion:nil];
}

- (void)updateSectionForCategory:(NSUInteger)category withEntry:(id)entry {
    if (category == YTTKSettingsSection) {
        [self updateYTTKSectionWithEntry:entry];
        return;
    }
    %orig;
}

%end

// ─── Constructor ─────────────────────────────────────────────────────────────

%ctor {
    %init;
}
