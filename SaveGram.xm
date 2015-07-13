#import "SaveGram.h"
#import "MBProgressHUD.h"

#define SGLOG(fmt, ...) NSLog((@"[SaveGram] %s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
static NSString *kSaveGramSaveString = @"Save";
static NSString *kSaveGramAllowDefaultsKey = @"SaveGram.Allow";

/*
 _______  __   __  ______    ______    _______  __    _  _______ 
|       ||  | |  ||    _ |  |    _ |  |       ||  |  | ||       |
|       ||  | |  ||   | ||  |   | ||  |    ___||   |_| ||_     _|
|       ||  |_|  ||   |_||_ |   |_||_ |   |___ |       |  |   |  
|      _||       ||    __  ||    __  ||    ___||  _    |  |   |  
|     |_ |       ||   |  | ||   |  | ||   |___ | | |   |  |   |  
|_______||_______||___|  |_||___|  |_||_______||_|  |__|  |___|  
*/
%group CurrentSupportPhase

%hook IGActionSheet

- (void)show {
 	AppDelegate *instagramAppDelegate = [UIApplication sharedApplication].delegate;
 	IGRootViewController *rootViewController = (IGRootViewController *)((IGShakeWindow *)instagramAppDelegate.window).rootViewController;
 	UIViewController *topMostViewController = rootViewController.topMostViewController;

 	// good classes = IGMainFeedViewController, IGSingleFeedViewController, IGDirectedPostViewController
 	// (some IGViewController, some IGFeedViewController)
 	BOOL isNotInWebViewController = ![topMostViewController isKindOfClass:[%c(IGWebViewController) class]];
 	BOOL isNotInProfileViewController = ![topMostViewController isKindOfClass:[%c(IGUserDetailViewController) class]];

 	if (isNotInWebViewController && isNotInProfileViewController) {
 		SGLOG(@"adding Save button to action sheet %@", self);
		[self addButtonWithTitle:kSaveGramSaveString style:0];
	}

	%orig();
}

%end

static NSURL * savegram_highestResolutionURLFromVersionArray(NSArray *versions) {
	NSURL *highestResAvailableVersion;
	CGFloat highResAvailableArea;
	for (NSDictionary *versionDict in versions) {
		CGFloat height = [versionDict[@"height"] floatValue];
		CGFloat width = [versionDict[@"width"] floatValue];
		CGFloat res = height * width;

		if (res > highResAvailableArea) {
			highResAvailableArea = res;
			highestResAvailableVersion = [NSURL URLWithString:versionDict[@"url"]];
		}
	}

	SGLOG(@"%@ has highest resolution available in %@", highestResAvailableVersion, versions);
	return highestResAvailableVersion;
}

static BOOL savegram_hasAllowedOutOfDateVersions() {
	NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
	return [standardUserDefaults boolForKey:kSaveGramAllowDefaultsKey];
} 

static void savegram_setAllowedOutOfDateVersions(BOOL value) {
	NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
	[standardUserDefaults setBool:value forKey:kSaveGramAllowDefaultsKey];
}

static void inline savegram_saveMediaFromPost(IGPost *post) {
	if ([%c(AFNetworkReachabilityManager) sharedManager].networkReachabilityStatus == AFNetworkReachabilityStatusNotReachable) {
 		SGLOG(@"networking not reachable");
		UIAlertView *noInternetAlert = [[UIAlertView alloc] initWithTitle:@"SaveGram" message:@"Check your internet connection and try again, Instagram may also be having issues." delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil];
		[noInternetAlert show];
		[noInternetAlert release];
		return;
	}

	UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
	MBProgressHUD __block *saveGramHUD = [MBProgressHUD showHUDAddedTo:keyWindow animated:YES];
	saveGramHUD.animationType = MBProgressHUDAnimationZoom;
	saveGramHUD.labelText = @"Saving post...";

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
		if (post.mediaType == 1) { // photo
			NSURL *imageURL = savegram_highestResolutionURLFromVersionArray((NSArray *)post.photo.imageVersions);
			UIImage *postImage = [UIImage imageWithData:[NSData dataWithContentsOfURL:imageURL]];
			IGAssetWriter *postImageAssetWriter = [[%c(IGAssetWriter) alloc] initWithImage:postImage metadata:nil];
			[postImageAssetWriter writeToInstagramAlbum];
	 		SGLOG(@"wrote image %@ to Instagram album", postImage);

		    dispatch_async(dispatch_get_main_queue(), ^{
		    	saveGramHUD.labelText = @"Saved!";
		        [saveGramHUD hide:YES afterDelay:1.0];
		    });
		}

		else { // video
			NSURL *videoURL = savegram_highestResolutionURLFromVersionArray((NSArray *)post.video.videoVersions);
			NSURLSessionTask *videoDownloadTask = [[NSURLSession sharedSession] downloadTaskWithURL:videoURL completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
				NSFileManager *fileManager = [NSFileManager defaultManager];
			    NSURL *videoDocumentsURL = [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
			    NSURL *videoSavedURL = [videoDocumentsURL URLByAppendingPathComponent:[videoURL lastPathComponent]];
			    [fileManager moveItemAtURL:location toURL:videoSavedURL error:&error];

			    [%c(IGAssetWriter) writeVideoToInstagramAlbum:videoSavedURL completionBlock:nil];
		 		SGLOG(@"wrote video %@ to Instagram album", videoSavedURL);

				dispatch_async(dispatch_get_main_queue(), ^{
			    	saveGramHUD.labelText = @"Saved!";
    		        [saveGramHUD hide:YES afterDelay:1.0];
			    });
			}];

			[videoDownloadTask resume];
		}
	});
}

/*
 ______   ___   ______    _______  _______  _______ 
|      | |   | |    _ |  |       ||       ||       |
|  _    ||   | |   | ||  |    ___||       ||_     _|
| | |   ||   | |   |_||_ |   |___ |       |  |   |  
| |_|   ||   | |    __  ||    ___||      _|  |   |  
|       ||   | |   |  | ||   |___ |     |_   |   |  
|______| |___| |___|  |_||_______||_______|  |___|  
*/
%hook IGDirectedPostViewController

- (void)actionSheetDismissedWithButtonTitled:(NSString *)title {
	if ([title isEqualToString:kSaveGramSaveString]) {
 		SGLOG(@"saving media from Direct message");
		IGPost *post = self.post;
		savegram_saveMediaFromPost(post);
	}

	else {
		%orig(title);
	}
}

%end

%hook IGFeedItemActionCell

/*
 _______  _______  _______  ______  
|       ||       ||       ||      | 
|    ___||    ___||    ___||  _    |
|   |___ |   |___ |   |___ | | |   |
|    ___||    ___||    ___|| |_|   |
|   |    |   |___ |   |___ |       |
|___|    |_______||_______||______| 
*/
- (void)actionSheetDismissedWithButtonTitled:(NSString *)title {
	if ([title isEqualToString:kSaveGramSaveString]) {
 		SGLOG(@"saving media from Feed post");
		IGFeedItem *post = self.feedItem;
		savegram_saveMediaFromPost(post);
	}

	else {
		%orig(title);
	}
}

%end

%end // %group CurrentSupportPhase

static NSInteger kSaveGramCompatibilityViewTag = 1213;

@interface SaveGramAlertViewDelegate : NSObject <UIAlertViewDelegate>

@end

@implementation  SaveGramAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (buttonIndex != alertView.cancelButtonIndex) {
		if (alertView.tag != kSaveGramCompatibilityViewTag) {
			if ([[alertView buttonTitleAtIndex:buttonIndex] isEqualToString:@"Cydia"]) {
				[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"cydia://package/com.example.package"]];
			}

			else {
				savegram_setAllowedOutOfDateVersions(YES);

				UIAlertView *compatibilityConfirmationView = [[[UIAlertView alloc] initWithTitle:@"SaveGram Compatibility" message:@"Please restart Instagram to run SaveGram anyway. This is not recommended: be prepared to still downgrade to a compatibility package from Cydia, if needed." delegate:self cancelButtonTitle:@"Dismiss" otherButtonTitles:@"Quit App", nil] autorelease];
				compatibilityConfirmationView.tag = kSaveGramCompatibilityViewTag;
				[compatibilityConfirmationView show];
			}
		}

		else {
			NSURL *URL = [NSURL URLWithString:@"instagram://"];

			Class pClass = NSClassFromString(@"BKSSystemService");
			id service = [[pClass alloc] init];

			SEL pSelector = NSSelectorFromString(@"openURL:application:options:clientPort:withResult:");
			NSMethodSignature *signature = [service methodSignatureForSelector:pSelector];
			NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
			invocation.target = service;
			NSString *app = @"com.burbn.instagram";
			[invocation setSelector:pSelector];
			[invocation setArgument:&URL atIndex:2];
			[invocation setArgument:&app atIndex:3];
			id i = [service performSelector:NSSelectorFromString(@"createClientPort")];
			[invocation setArgument:&i atIndex:5];
			[invocation invoke];
			exit(0);
		}
	}
}

@end

static SaveGramAlertViewDelegate * savegram_compatibilityAlertDelegate;
static BOOL savegram_shouldShowCompatibilityAlert;

%hook AppDelegate

- (void)applicationDidFinishLaunching:(UIApplication *)application {
	%orig();

	NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
	NSComparisonResult newestWaveVersionComparisonResult = [version compare:@"7.1.1" options:NSNumericSearch];
	savegram_compatibilityAlertDelegate = [[SaveGramAlertViewDelegate alloc] init];


	if (newestWaveVersionComparisonResult != NSOrderedDescending) {
		if (savegram_hasAllowedOutOfDateVersions()) {
			%init(CurrentSupportPhase);
		}
	}

		UIAlertView *compatibilityWarningView = [[[UIAlertView alloc] initWithTitle:@"SaveGram Compatibility" message:@"You are running an out-of-date version of Instagram. Please downgrade to a previous SaveGram package in Cydia, or upgrade Instagram." delegate:savegram_compatibilityAlertDelegate cancelButtonTitle:@"Cancel" otherButtonTitles:@"Run", @"Cydia", nil] autorelease];
		[compatibilityWarningView show];
}

%end

/*                                                                                                     
 _______  _______  _______  ______   
|       ||       ||       ||    _ |  
|       ||_     _||   _   ||   | ||  
|       |  |   |  |  | |  ||   |_||_ 
|      _|  |   |  |  |_|  ||    __  |
|     |_   |   |  |       ||   |  | |
|_______|  |___|  |_______||___|  |_|
*/
%ctor {
	NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
	NSComparisonResult newestWaveVersionComparisonResult = [version compare:@"7.1.1" options:NSNumericSearch];
	SGLOG(@"Instagram %@, comparison result to last official supported build (7.1.1): %i", version, (int)newestWaveVersionComparisonResult);

	if (newestWaveVersionComparisonResult != NSOrderedDescending) {
		if (savegram_hasAllowedOutOfDateVersions()) {
			%init(CurrentSupportPhase);
		}

		else {
			savegram_shouldShowCompatibilityAlert = YES;
		}
	}

	else {
		%init(CurrentSupportPhase);
	}
}
