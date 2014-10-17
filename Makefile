THEOS_PACKAGE_DIR_NAME = debs
TARGET = :clang
ARCHS = armv7 armv7s arm64

include theos/makefiles/common.mk

TWEAK_NAME = SaveGram
SaveGram_FILES = SaveGram.xm ALAssetsLibrary-CustomPhotoAlbum/ALAssetsLibrary-CustomPhotoAlbum.m
SaveGram_FRAMEWORKS = UIKit AssetsLibrary MobileCoreServices
ALAssetsLibrary-CustomPhotoAlbum.m_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

before-stage::
	find . -name ".DS_Store" -delete
internal-after-install::
	install.exec "killall -9 Instagram"
