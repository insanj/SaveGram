#import <UIKit/UIKit.h>
#import <AssetsLibrary/AssetsLibrary.h>

@interface IGPost

// iOS 7
@property (nonatomic, readwrite) int mediaType; 		// 1 = picture, 2 = video
+ (int)videoVersionForCurrentNetworkConditions;  // Introducted in 5.0.9
+ (int)fullSizeVideoVersionForDevice;			// Removed in 5.0.9
+ (int)fullSizeImageVersionForDevice;

// iOS 8
-(id)imageURLForFullSizeImage;

- (NSURL *)imageURLForImageVersion:(int)version;
- (NSURL *)videoURLForVideoVersion:(int)version;
@end

@interface IGFeedItem : IGPost
@end

@protocol IGActionSheetDelegate
@optional
-(void)actionSheetFinishedHiding;
@required
-(void)actionSheetDismissedWithButtonTitled:(NSString *)title;
@end

@interface IGFeedItemActionCell <IGActionSheetDelegate>
@property (nonatomic,retain) IGFeedItem *feedItem;
-(void)actionSheetDismissedWithButtonTitled:(NSString *)title;
@end

@interface IGActionSheet : UIWindow
@property (nonatomic, retain) UIView *overlayView;
@property (nonatomic, retain) UIView *buttonView;
@property (nonatomic, retain) NSMutableArray *buttons;
@property (assign, nonatomic, weak) id actionDelegate;

// iOS 8
+(void)showWithDelegate:(id)arg1;
+(void)showWithCallback:(id)arg1;

// iOS 7
+(void)showWithTitle:(NSString *)title delegate:(id)delegate;
+(void)showWithTitle:(NSString *)title withCallback:(id)callback;

+(void)addButtonWithTitle:(NSString *)title style:(int)style;
+(void)dismissAnimated:(BOOL)animated;
-(void)showWithTitle:(NSString *)title;
-(void)addButtonWithTitle:(NSString *)title style:(int)style;
-(void)showWithTitle:(NSString *)title;
-(void)buttonTapped:(UIButton *)button;
-(void)dismissAnimated:(BOOL)animated;
-(void)setActionDelegate:(id)delegate;
-(void)setButtons:(NSMutableArray *)arg1;
@end
