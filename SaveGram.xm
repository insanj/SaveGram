#import "SaveGram.h"

#define SGLOG(fmt, ...) NSLog((@"[SaveGram] %s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
static NSString *kSaveGramSaveString = @"Save";

/*
 _______  __   __  ______    ______    _______  __    _  _______ 
|       ||  | |  ||    _ |  |    _ |  |       ||  |  | ||       |
|       ||  | |  ||   | ||  |   | ||  |    ___||   |_| ||_     _|
|       ||  |_|  ||   |_||_ |   |_||_ |   |___ |       |  |   |  
|      _||       ||    __  ||    __  ||    ___||  _    |  |   |  
|     |_ |       ||   |  | ||   |  | ||   |___ | | |   |  |   |  
|_______||_______||___|  |_||___|  |_||_______||_|  |__|  |___|  
*/

BOOL isNotInWebViewController = NO;
BOOL isNotInProfileViewController = NO;

%group CurrentSupportPhase

// Check topMostViewController
%hook IGWebViewController
- (void)loadCurrentTargetURL {
	isNotInWebViewController = YES;
	%orig;
}
// to be sure that it returns NO again
- (void)dismissWithCompletionHandler:(id)arg1 {
	isNotInWebViewController = NO;
	%orig;
}
%end

%hook IGUserDetailViewController
- (void)viewWillAppear:(BOOL)arg1 {
	isNotInProfileViewController = YES;
	%orig;
}
- (void)viewWillDisappear:(BOOL)arg1 {
	isNotInProfileViewController = NO;
	%orig;
}
%end

%hook IGActionSheet

 - (void)show {
 	// AppDelegate *instagramAppDelegate = [UIApplication sharedApplication].delegate;
 	// IGRootViewController *rootViewController = (IGRootViewController *)((IGShakeWindow *)instagramAppDelegate.window).rootViewController;
 	// UIViewController *topMostViewController = rootViewController.topMostViewController;

 	// good classes = IGMainFeedViewController, IGSingleFeedViewController, IGDirectedPostViewController
 	// (some IGViewController, some IGFeedViewController)
 	// BOOL isNotInWebViewController = ![topMostViewController isKindOfClass:[%c(IGWebViewController) class]];
 	// BOOL isNotInProfileViewController = ![topMostViewController isKindOfClass:[%c(IGUserDetailViewController) class]];

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

static void inline savegram_saveMediaFromPost(IGPost *post) {
	if ([%c(AFNetworkReachabilityManager) sharedManager].networkReachabilityStatus == AFNetworkReachabilityStatusNotReachable) {
 		SGLOG(@"networking not reachable");
		UIAlertView *noInternetAlert = [[UIAlertView alloc] initWithTitle:@"SaveGram" message:@"Check your internet connection and try again, Instagram may also be having issues." delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil];
		[noInternetAlert show];
		[noInternetAlert release];
	}

	else if (post.mediaType == 1) {
		NSURL *imageURL = savegram_highestResolutionURLFromVersionArray((NSArray *)post.photo.imageVersions);
		UIImage *postImage = [UIImage imageWithData:[NSData dataWithContentsOfURL:imageURL]];
		IGAssetWriter *postImageAssetWriter = [[%c(IGAssetWriter) alloc] initWithImage:postImage metadata:nil];
		[postImageAssetWriter writeToInstagramAlbum];
 		SGLOG(@"wrote image %@ to Instagram album", postImage);
	}

	else {
		NSURL *videoURL = savegram_highestResolutionURLFromVersionArray((NSArray *)post.video.videoVersions);
		NSURLSessionTask *videoDownloadTask = [[NSURLSession sharedSession] downloadTaskWithURL:videoURL completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
			NSFileManager *fileManager = [NSFileManager defaultManager];
		    NSURL *videoDocumentsURL = [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
		    NSURL *videoSavedURL = [videoDocumentsURL URLByAppendingPathComponent:[videoURL lastPathComponent]];
		    [fileManager moveItemAtURL:location toURL:videoSavedURL error:&error];

		    [%c(IGAssetWriter) writeVideoToInstagramAlbum:videoSavedURL completionBlock:nil];
	 		SGLOG(@"wrote video %@ to Instagram album", videoSavedURL);
		}];

		[videoDownloadTask resume];
	}
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
	NSComparisonResult newestWaveVersionComparisonResult = [version compare:@"6.13.0" options:NSNumericSearch];
	SGLOG(@"Instagram %@, comparison result to last official supported build (6.13.0): %i", version, (int)newestWaveVersionComparisonResult);

	if (newestWaveVersionComparisonResult != NSOrderedDescending) {
		UIAlertView *compatibilityWarningView = [[UIAlertView alloc] initWithTitle:@"SaveGram Compatibility" message:@"You are running an old version of Instagram. It's recommended that you downgrade to a legacy SaveGram package, or upgrade Instagram." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[compatibilityWarningView show];
		[compatibilityWarningView release];
	}

	else {
		SGLOG(@"Detected Instagram running on current supported version %@.", version);
	}

	%init(CurrentSupportPhase);
}
