#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "substrate.h"

#define SGLOG(fmt, ...) NSLog((@"[SaveGram] %s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)

// iOS 8.3+
@interface IGViewController : UIViewController
@end

@interface IGUserDetailViewController : IGViewController
@end

@interface IGWebViewController : IGViewController
@end

@interface IGRootViewController : UIViewController

- (id)topMostViewController;

@end

@interface IGShakeWindow : UIWindow

- (id)rootViewController; // IGRootViewController

@end

@interface AppDelegate : NSObject

- (void)startMainAppWithMainFeedSource:(id)source animated:(BOOL)animated;
- (id)window; // IGShakeWindow

@end

@interface IGPhoto : NSObject

@property (strong, nonatomic) NSArray *imageVersions;

- (id)imageURLForSize:(CGSize)size;

@end

@interface IGVideo : NSObject

@property (strong, nonatomic) NSArray *videoVersions;
@property (readonly, nonatomic) double videoDuration;

- (id)videoURLForVideoVersion:(int)version;

@end

@interface IGPost : NSObject

// iOS 7
@property (nonatomic, readwrite) int mediaType; // 1 = picture, 2 = video
+ (int)videoVersionForCurrentNetworkConditions; // Introducted in 5.0.9
+ (int)fullSizeVideoVersionForDevice;			// Removed in 5.0.9
+ (int)fullSizeImageVersionForDevice;

// 6.1.2
- (id)imageURLForFullSizeImage;

// 6.5.x
- (id)imageURLForImageIndex:(NSInteger)index;
- (id)imageURLForSize:(CGSize)size;

- (NSURL *)imageURLForImageVersion:(int)version;
- (NSURL *)videoURLForVideoVersion:(int)version;

// 6.6.x
@property (strong, nonatomic) IGPhoto *photo;
@property (strong, nonatomic) IGVideo *video;

@end

@interface IGFeedItem : IGPost

@property (retain) NSArray *items;

- (NSString *)itemId;

@end

@protocol IGActionSheetDelegate
@optional
- (void)actionSheetFinishedHiding;
@required
- (void)actionSheetDismissedWithButtonTitled:(NSString *)title;
@end

@interface IGFeedItemActionCell : UICollectionViewCell <IGActionSheetDelegate>

@property (nonatomic,retain) IGFeedItem *feedItem;
//removed from this class. moved to IGFeedViewController
//- (void)actionSheetDismissedWithButtonTitled:(NSString *)title;

@end

@interface IGActionSheet : UIWindow

@property (nonatomic, retain) UIView *overlayView;
@property (nonatomic, retain) UIView *buttonView;
@property (nonatomic, retain) NSMutableArray *buttons;
@property (nonatomic, retain) NSObject<IGActionSheetDelegate>* actionDelegate;

+ (instancetype)sharedIGActionSheet;

// iOS 8
+ (void)showWithDelegate:(id)arg1;
+ (void)showWithCallback:(id)arg1;

// iOS 7
+ (void)showWithTitle:(NSString *)title delegate:(id)delegate;
+ (void)showWithTitle:(NSString *)title withCallback:(id)callback;

+ (void)addButtonWithTitle:(NSString *)title style:(int)style;
+ (void)dismissAnimated:(BOOL)animated;
- (void)showWithTitle:(NSString *)title;
//the following method appears to have been removed as of 7.13
- (void)addButtonWithTitle:(NSString *)title style:(int)style;
- (void)showWithTitle:(NSString *)title;
- (void)buttonTapped:(UIButton *)button;
- (void)dismissAnimated:(BOOL)animated;
- (void)setButtons:(NSMutableArray *)arg1;
- (void)layoutHeaderAndButtons;
- (void)animateVisible:(BOOL)visible;

@end

@interface IGAssetWriter : NSObject {
	NSMutableDictionary* _metadata; 
}

@property (nonatomic,retain) UIImage *image;
// @property (nonatomic,retain) CLLocation* location; 				//@synthesize location=_location - In the implementation block
+ (void)writeVideo:(id)arg1 toInstagramAlbum:(BOOL)arg2 completionBlock:(id)arg3;
+ (void)writeVideoToCameraRoll:(id)arg1;
+ (void)writeVideoToInstagramAlbum:(id)arg1 completion:(id)arg2;
- (id)initWithImage:(id)arg1 metadata:(id)arg2;
- (void)writeToInstagramAlbum:(BOOL)arg1;
- (void)showLibraryAccessMessage;
- (void)writeToCameraRoll;
- (void)writeToInstagramAlbum;
- (id)init;

@end

@interface IGDirectedPostViewController : UIViewController

@property (nonatomic, retain) IGPost *post;

@end

@interface IGLocaleHelper : NSObject

+ (BOOL)localeIsEnglish;
+ (BOOL)localeIsRussian;
+ (BOOL)keyboardLocaleIsFarEast;
+ (id)localeForCurrentLanguage;
+ (BOOL)isLocale:(id)arg1 inLocaleArray:(id)arg2;
+ (id)localeForCurrentKeyboard;
+ (BOOL)localeHasSpecialCharacters;
+ (BOOL)localeIsThai;

@end

@interface IGFNFBandwidthProvider : NSObject

- (long long)currentReachabilityState;

@end

@interface IGImageURL : NSObject

- (NSURL *)url;
- (double)width;
- (double)height;

@end

@interface UIApplication ()

- (void)terminateWithSuccess;

@end

@interface IGPostItem : NSObject

@property (readonly, nonatomic) IGPhoto *photo;
@property (readonly, nonatomic) IGVideo *video;

@end

@interface IGFeedItemPageCell_DEPRECATED : UICollectionViewCell

@property (readonly, nonatomic) IGFeedItem *feedItem;

- (long long)getCurrentPage;

@end
