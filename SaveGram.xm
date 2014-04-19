#import "SaveGram.h"

%hook IGActionSheet

// Not sure if the IGActionSheet is used in any case besides image/video options,
// but if it was, the .topMostViewController or .delegate properties might be nice
-(void)showWithTitle:(NSString *)title {
	NSLog(@"[SaveGram] Detected action sheet from item, adding save option...");
	[self addButtonWithTitle:@"Save" style:0];

	%orig(title);
}

%end

%hook IGFeedItemActionCell

-(void)actionSheetDismissedWithButtonTitled:(NSString *)title {
	if ([title isEqualToString:@"Save"]) {

		// Instead of opting for intelligent version checking when launching Instagram
		// (ala SlickGram), this segment uses try/catches to prevent crashing and only
		// notify the user when things /actually/ aren't working.
		@try{
			IGFeedItem *post = self.feedItem;
			NSLog(@"[SaveGram] Detected dismissal of action sheet with Save option, trying to save %@...", post);

			if (post.mediaType == 1) {
				NSURL *imageURL = [post imageURLForImageVersion:[%c(IGPost) fullSizeImageVersionForDevice]];
				UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:imageURL]];

				UIImageWriteToSavedPhotosAlbum(image, nil, NULL, NULL);
				NSLog(@"[SaveGram] Finished saving photo (%@) to photo library.", image);
			}

			else {
			//	NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
			//	NSComparisonResult *comparison = [version compare:@"5.0.9" options:NSNumericSearch];
			//	if (version == NSOrderedSame || version == NSOrderedDescending)

				int videoVersion;
				if ([%c(IGPost) respondsToSelector:@selector(fullSizeVideoVersionForDevice)]) {
					videoVersion = [%c(IGPost) fullSizeVideoVersionForDevice];
				}

				else {
					videoVersion = [%c(IGPost) videoVersionForCurrentNetworkConditions];
				}

				NSURL *videoURL =  [post videoURLForVideoVersion:videoVersion];
				NSURLSessionTask *videoDownloadTask = [[NSURLSession sharedSession] downloadTaskWithURL:videoURL completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
					NSFileManager *fileManager = [NSFileManager defaultManager];
				    NSURL *videoDocumentsURL = [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
				    NSURL *videoSavedURL = [videoDocumentsURL URLByAppendingPathComponent:[videoURL lastPathComponent]];
				    [fileManager moveItemAtURL:location toURL:videoSavedURL error:&error];

					UISaveVideoAtPathToSavedPhotosAlbum(videoSavedURL.path, self, @selector(savegram_removeVideoAtPath:didFinishSavingWithError:contextInfo:), NULL);
				}];

				[videoDownloadTask resume];
			}
		} // end @try

		@catch (NSException *e) {
			UIAlertView *errorView = [[UIAlertView alloc] initWithTitle:@"Oops!" message:[NSString stringWithFormat:@"Looks like SaveGram had trouble saving this post. Please send the following error message to @insanj: %@", e.reason] delegate:nil cancelButtonTitle:@"Dimiss" otherButtonTitles:nil];
			[errorView show];
			[errorView release];
		}
	}

	else {
		%orig(title);
	}
}

%new - (void)savegram_removeVideoAtPath:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
	if (error) {
		NSLog(@"[SaveGram] Couldn't save video to photo library: %@", error);
		return;
	}

	[[NSFileManager defaultManager] removeItemAtPath:videoPath error:&error];
	if (error) {
		NSLog(@"[SaveGram] Couldn't remove video from temporary location: %@", error);
		return;
	}

	NSLog(@"[SavedGram] Finished saving video to photo library.");
}

%end
