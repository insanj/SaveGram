THEOS_PACKAGE_DIR_NAME = debs
TARGET = iphone:clang:latest:7.0
ARCHS = armv7 arm64

include theos/makefiles/common.mk

TWEAK_NAME = SaveGram
SaveGram_FILES = SaveGram.xm MBProgressHUD.m
SaveGram_FRAMEWORKS = Foundation UIKit CoreGraphics

include $(THEOS_MAKE_PATH)/tweak.mk

before-stage::
	find . -name ".DS_Store" -delete
internal-after-install::
	install.exec "killall -9 Instagram"
