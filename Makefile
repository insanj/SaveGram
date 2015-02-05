THEOS_PACKAGE_DIR_NAME = debs
TARGET = :clang
ARCHS = armv7 arm64

include theos/makefiles/common.mk

TWEAK_NAME = SaveGram
SaveGram_FILES = SaveGram.xm
SaveGram_FRAMEWORKS = Foundation UIKit AssetsLibrary

include $(THEOS_MAKE_PATH)/tweak.mk

before-stage::
	find . -name ".DS_Store" -delete
internal-after-install::
	install.exec "killall -9 Instagram"
