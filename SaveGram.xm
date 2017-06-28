#import "SaveGram.h"
#import "MBProgressHUD.h"

#define SGLOG(fmt, ...) NSLog((@"[SaveGram] %s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
static NSString *kSaveGramSaveString = @"Save";
static NSString *kSaveGramAllowVersionDefaultsKey = @"SaveGram.LastAllowedVersion";

/*
 _______  ______   ______     _______  __   __  _______  _______  _______  __    _
|   _   ||      | |      |   |  _    ||  | |  ||       ||       ||       ||  |  | |
|  |_|  ||  _    ||  _    |  | |_|   ||  | |  ||_     _||_     _||   _   ||   |_| |
|       || | |   || | |   |  |       ||  |_|  |  |   |    |   |  |  | |  ||       |
|       || |_|   || |_|   |  |  _   | |       |  |   |    |   |  |  |_|  ||  _    |
|   _   ||       ||       |  | |_|   ||       |  |   |    |   |  |       || | |   |
|__| |__||______| |______|   |_______||_______|  |___|    |___|  |_______||_|  |__|
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
		[[%c(IGActionSheet) sharedIGActionSheet] addButtonWithTitle:kSaveGramSaveString style:0];
	}

	%orig();
}

%end

/*
 _______  _______  _______    _______  _______  _______  _______
|       ||       ||       |  |       ||       ||       ||       |
|    ___||    ___||_     _|  |    _  ||   _   ||  _____||_     _|
|   | __ |   |___   |   |    |   |_| ||  | |  || |_____   |   |
|   ||  ||    ___|  |   |    |    ___||  |_|  ||_____  |  |   |
|   |_| ||   |___   |   |    |   |    |       | _____| |  |   |
|_______||_______|  |___|    |___|    |_______||_______|  |___|
&*/
/*
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
*/
static NSString * savegram_lastVersionUserConfirmedWasSupported() {
	NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
	return [standardUserDefaults objectForKey:kSaveGramAllowVersionDefaultsKey];
}

static void savegram_setLastVersionUserConfirmedWasSupported(NSString *value) {
	NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
	[standardUserDefaults setObject:value forKey:kSaveGramAllowVersionDefaultsKey];
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
    NSString* urlStr = nil;
    if (post.mediaType == 1) { // photo
      IGPhoto* photo = [post photo];
   		NSArray* imageVersions = [photo imageVersions];
   		IGTypedURL* url = [imageVersions lastObject];
   		urlStr = [(NSURL*)[url url] absoluteString];
			NSURL *imageURL = [NSURL URLWithString:urlStr];
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
      IGVideo* video = [post video];
   		NSArray* videoVersions = [video videoVersions];
   		NSDictionary* urlDict = [videoVersions firstObject];
   		urlStr = [urlDict objectForKey:@"url"];
			NSURL *videoURL = [NSURL URLWithString:urlStr];
			NSURLSessionTask *videoDownloadTask = [[NSURLSession sharedSession] downloadTaskWithURL:videoURL completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
				NSFileManager *fileManager = [NSFileManager defaultManager];
			    NSURL *videoDocumentsURL = [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
			    NSURL *videoSavedURL = [videoDocumentsURL URLByAppendingPathComponent:[videoURL lastPathComponent]];
			    [fileManager moveItemAtURL:location toURL:videoSavedURL error:&error];

			    [%c(IGAssetWriter) writeVideoToInstagramAlbum:videoSavedURL completion:nil];
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

%hook IGMediaManager

/*
 _______  _______  _______  ______
|       ||       ||       ||      |
|    ___||    ___||    ___||  _    |
|   |___ |   |___ |   |___ | | |   |
|    ___||    ___||    ___|| |_|   |
|   |    |   |___ |   |___ |       |
|___|    |_______||_______||______|
*/

- (void)handleActionSheetDismissedWithButtonTitled:(id)title forFeedItem:(id)feedItem navigationController:(id)navController sourceName:(NSString*)source {
  if ([title isEqualToString:kSaveGramSaveString]) {
 		SGLOG(@"saving media from Feed post");

		IGFeedItem *post = feedItem;
		savegram_saveMediaFromPost(post);
	}

	else {
		%orig(title,feedItem,navController,source);
	}
}

%end

%end // %group CurrentSupportPhase

/*
 _______  _______  __   __  _______  _______  _______  ___   _______  ___   ___      ___   _______  __   __
|       ||       ||  |_|  ||       ||   _   ||       ||   | |  _    ||   | |   |    |   | |       ||  | |  |
|       ||   _   ||       ||    _  ||  |_|  ||_     _||   | | |_|   ||   | |   |    |   | |_     _||  |_|  |
|       ||  | |  ||       ||   |_| ||       |  |   |  |   | |       ||   | |   |    |   |   |   |  |       |
|      _||  |_|  ||       ||    ___||       |  |   |  |   | |  _   | |   | |   |___ |   |   |   |  |_     _|
|     |_ |       || ||_|| ||   |    |   _   |  |   |  |   | | |_|   ||   | |       ||   |   |   |    |   |
|_______||_______||_|   |_||___|    |__| |__|  |___|  |___| |_______||___| |_______||___|   |___|    |___|
*/
static NSInteger kSaveGramCompatibilityViewTag = 1213;

@interface SaveGramAlertViewDelegate : NSObject <UIAlertViewDelegate>

@end

@implementation  SaveGramAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (buttonIndex != alertView.cancelButtonIndex) {
		if (alertView.tag != kSaveGramCompatibilityViewTag) {
			if ([[alertView buttonTitleAtIndex:buttonIndex] isEqualToString:@"Cydia"]) {
				[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"cydia://package/com.insanj.savegram"]];
			}

			else {
				NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
				savegram_setLastVersionUserConfirmedWasSupported(version);

				UIAlertView *compatibilityConfirmationView = [[[UIAlertView alloc] initWithTitle:@"SaveGram Compatibility" message:@"Instagram will close to run SaveGram. This is not recommended: be prepared to still downgrade to a compatibility package from Cydia, if needed." delegate:self cancelButtonTitle:@"Dismiss" otherButtonTitles:@"Restart", nil] autorelease];
				compatibilityConfirmationView.tag = kSaveGramCompatibilityViewTag;
				[compatibilityConfirmationView show];
			}
		}

		else {
			// BKSSystemService *backBoardService = [[%c(BKSSystemService) alloc] init];
			// [backBoardService performSelector:@selector(openApplication:options:withResult:) withObject:@"com.burbn.instagram" afterDelay:0.5];
			// [backBoardService openApplication:@"com.apple.mobilesafari" options:nil withResult:nil];
			// [backBoardService openURL:[NSURL URLWithString:@"instagram://app"] application:@"com.burbn.instagram" options:0 clientPort:[backBoardService createClientPort] withResult:NULL];
			exit(0);
		}
	}
}

@end

static SaveGramAlertViewDelegate * savegram_compatibilityAlertDelegate;

%group Compatibility

%hook AppDelegate

- (void)startMainAppWithMainFeedSource:(id)source animated:(BOOL)animated {
	%orig();

	SGLOG(@"");
	savegram_compatibilityAlertDelegate = [[SaveGramAlertViewDelegate alloc] init];
	UIAlertView *compatibilityWarningView = [[[UIAlertView alloc] initWithTitle:@"SaveGram Compatibility" message:@"You are running an out-of-date version of Instagram. Please downgrade to a previous SaveGram package in Cydia, or upgrade Instagram." delegate:savegram_compatibilityAlertDelegate cancelButtonTitle:@"Cancel" otherButtonTitles:@"Run", @"Cydia", nil] autorelease];
	[compatibilityWarningView show];
}

%end

%end // %group Compatibility

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

	// If the current version of Instagram is LOWER (not EQUAL TO or HIGHER) than 7.1.1, they should be running a compatibility package
	if (newestWaveVersionComparisonResult == NSOrderedAscending) {
		NSString *lastVersionConfirmed = savegram_lastVersionUserConfirmedWasSupported();
		NSComparisonResult lastConfirmedCompatibilityResult = [version compare:savegram_lastVersionUserConfirmedWasSupported() options:NSNumericSearch];
		SGLOG(@"Running out-of-date version of Instagram. Last version that we were allowed to run SaveGram on was %@, which compares to the current version as: %i", lastVersionConfirmed, (int)lastConfirmedCompatibilityResult);

		// If the last time the user confirmed running an out-of-date Instagram was in a LOWER
		if (!lastVersionConfirmed || lastConfirmedCompatibilityResult == NSOrderedDescending) {
			%init(Compatibility);
			return;
		}
	}

	%init(CurrentSupportPhase);
}
