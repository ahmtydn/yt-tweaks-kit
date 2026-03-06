ifeq ($(THEOS_PACKAGE_SCHEME),rootless)
	TARGET = iphone:clang:latest:15.0
else ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
	TARGET = iphone:clang:latest:15.0
else
	TARGET = iphone:clang:latest:15.0
endif
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = YouTube
FINALPACKAGE = 1
DEBUG = 0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = YTTweaksKit

# ──────────────────────────────────────────────────────────────────────────────
# Source Files
# To add a new module, simply append its .x file to this list.
# ──────────────────────────────────────────────────────────────────────────────
$(TWEAK_NAME)_FILES = \
	Core/YTTKConsoleLogStore.x \
	Core/YTTKModuleManager.x \
	Settings/YTTKSettings.x \
	Settings/YTTKSettingsController.x \
	Modules/AntiAbuse/YTTKAntiAbuse.x \
	Tweak.x

$(TWEAK_NAME)_CFLAGS = -fobjc-arc $(EXTRA_CFLAGS)

include $(THEOS_MAKE_PATH)/tweak.mk
