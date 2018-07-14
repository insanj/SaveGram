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

- (void)_show {
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

static NSURL * savegram_highestResolutionURLFromVersionArray(NSArray *versions) {
	NSURL *highestResAvailableVersion;
	CGFloat highResAvailableArea;

	for (id version in versions) {
		if ([version isKindOfClass:NSClassFromString(@"NSDictionary")]) {
			NSDictionary *versionDict = (NSDictionary *)version;
			CGFloat height = [versionDict[@"height"] floatValue];
			CGFloat width = [versionDict[@"width"] floatValue];
			CGFloat res = height * width;

			if (res > highResAvailableArea) {
				highResAvailableArea = res;
				highestResAvailableVersion = [NSURL URLWithString:versionDict[@"url"]];
			}
		} else if ([version isKindOfClass:NSClassFromString(@"IGImageURL")]) {
			IGImageURL *imageURL = (IGImageURL *)version;
			CGFloat height = [imageURL height];
			CGFloat width = [imageURL width];
			CGFloat res = height * width;

			if (res > highResAvailableArea) {
				highResAvailableArea = res;
				highestResAvailableVersion = [imageURL url];
			}
		}
	}

	SGLOG(@"%@ has highest resolution available in %@", highestResAvailableVersion, versions);
	return highestResAvailableVersion;
}

static NSString * savegram_lastVersionUserConfirmedWasSupported() {
	NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
	return [standardUserDefaults objectForKey:kSaveGramAllowVersionDefaultsKey];
} 

static void savegram_setLastVersionUserConfirmedWasSupported(NSString *value) {
	NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
	[standardUserDefaults setObject:value forKey:kSaveGramAllowVersionDefaultsKey];
}

static BOOL savegram_isPhotoFeedItem(IGFeedItem *item) {
	if (item.mediaType == 1) return YES;
	if (item.mediaType == 8) {
		IGVideo *video = item.video;
		if (video.videoDuration == 0) return YES;
	}
	return NO;
}

static BOOL savegram_isVideoFeedItem(IGFeedItem *item) {
	if (item.mediaType == 2) return YES;
	if (item.mediaType == 8) {
		IGVideo *video = item.video;
		if (video.videoDuration != 0) return YES;
	}
	return NO;
}

static void inline savegram_saveMediaFromFeedItem(IGFeedItem *item, int index) {
	if ([[[%c(IGFNFBandwidthProvider) alloc] init] currentReachabilityState] == 1) {
 		SGLOG(@"networking not reachable");
		UIAlertView *noInternetAlert = [[UIAlertView alloc] initWithTitle:@"SaveGram" message:@"Check your internet connection and try again, Instagram may also be having issues." delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil];
		[noInternetAlert show];
		return;
	}

	UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
	MBProgressHUD __block *saveGramHUD = [MBProgressHUD showHUDAddedTo:keyWindow animated:YES];
	saveGramHUD.animationType = MBProgressHUDAnimationZoom;
	saveGramHUD.labelText = @"Saving...";

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
		if (savegram_isPhotoFeedItem(item)) {
			IGPostItem *postItem = item.items[index];
			NSURL *imageURL = savegram_highestResolutionURLFromVersionArray(postItem.photo.imageVersions);
			UIImage *postImage = [UIImage imageWithData:[NSData dataWithContentsOfURL:imageURL]];
			IGAssetWriter *postImageAssetWriter = [[%c(IGAssetWriter) alloc] initWithImage:postImage metadata:nil];
			[postImageAssetWriter writeToInstagramAlbum];
	 		SGLOG(@"wrote image %@ to Instagram album", postImage);

		    	dispatch_async(dispatch_get_main_queue(), ^{
		    		saveGramHUD.labelText = @"Saved!";
			        [saveGramHUD hide:YES afterDelay:1.0];
			});
		} else if (savegram_isVideoFeedItem(item)) {
			IGPostItem *postItem = item.items[index];		
			NSURL *videoURL = savegram_highestResolutionURLFromVersionArray(postItem.video.videoVersions);
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
		} else {
			SGLOG(@"error resolving %@", item);
		}
	});
}

static NSMutableDictionary *SaveGramCurrentItemInfo;

%hook IGFeedItemPageCell_DEPRECATED // slides

- (void)pageMediaView:(id)arg1 itemDidDisappear:(IGPostItem *)arg2
{
	%orig;
	SaveGramCurrentItemInfo[self.feedItem.itemId] = @(self.getCurrentPage);
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

- (void)handleActionSheetDismissedWithButtonTitled:(NSString *)arg1 forFeedItem:(IGFeedItem *)arg2 navigationController:(id)arg3 sourceName:(id)arg4 position:(unsigned long long)arg5
{
	if ([arg1 isEqualToString:kSaveGramSaveString]) {
		SGLOG(@"saving media from Feed post %@", arg2);
		NSNumber *currentPage = SaveGramCurrentItemInfo[arg2.itemId];
		savegram_saveMediaFromFeedItem(arg2, currentPage ? currentPage.intValue : 0);
	} else {
		%orig;
	}
}

%end

/*
   Story
 */

%hook IGStoryItemActionsController

- (void)actionSheetDismissedWithButtonTitled:(NSString *)arg1
{
	id item = self.item;
	if ([arg1 isEqualToString:kSaveGramSaveString] && [item isKindOfClass:NSClassFromString(@"IGFeedItem")]) {
		IGFeedItem *feedItem = item;
		SGLOG(@"saving media from Story post %@", feedItem);
		savegram_saveMediaFromFeedItem(feedItem, 0);
		%orig(@"snakeninny"); // Continue playing story
	} else {
		%orig;
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

				UIAlertView *compatibilityConfirmationView = [[UIAlertView alloc] initWithTitle:@"SaveGram Compatibility" message:@"Instagram will close to run SaveGram. This is not recommended: be prepared to still downgrade to a compatibility package from Cydia, if needed." delegate:self cancelButtonTitle:@"Dismiss" otherButtonTitles:@"Restart", nil];
				compatibilityConfirmationView.tag = kSaveGramCompatibilityViewTag;
				[compatibilityConfirmationView show];
			}
		}

		else {
			[[UIApplication sharedApplication] terminateWithSuccess];
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
	UIAlertView *compatibilityWarningView = [[UIAlertView alloc] initWithTitle:@"SaveGram Compatibility" message:@"You are running an out-of-date version of Instagram. Please downgrade to a previous SaveGram package in Cydia, or upgrade Instagram." delegate:savegram_compatibilityAlertDelegate cancelButtonTitle:@"Cancel" otherButtonTitles:@"Run", @"Cydia", nil];
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

	SaveGramCurrentItemInfo = [@{} mutableCopy];

	%init(CurrentSupportPhase);
}
