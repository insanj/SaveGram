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
		IGFeedItem *post = self.feedItem;
		NSLog(@"[SaveGram] Detected dismissal of action sheet with Save option, trying to save %@...", post);

		if (post.mediaType == 1) {
			NSURL *imageURL = [post imageURLForImageVersion:[%c(IGPost) fullSizeImageVersionForDevice]];
			UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:imageURL]];

			UIImageWriteToSavedPhotosAlbum(image, nil, NULL, NULL);
			NSLog(@"[SaveGram] Finished saving photo (%@) to photo library.", image);
		}

		else {
			NSURL *videoURL = [post videoURLForVideoVersion:[%c(IGPost) fullSizeVideoVersionForDevice]];
			NSURLSessionTask *videoDownloadTask = [[NSURLSession sharedSession] downloadTaskWithURL:videoURL completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
				NSFileManager *fileManager = [NSFileManager defaultManager];
			    NSURL *videoDocumentsURL = [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
			    NSURL *videoSavedURL = [videoDocumentsURL URLByAppendingPathComponent:[videoURL lastPathComponent]];
			    [fileManager moveItemAtURL:location toURL:videoSavedURL error:&error];

				UISaveVideoAtPathToSavedPhotosAlbum(videoSavedURL.path, self, @selector(savegram_removeVideoAtPath:didFinishSavingWithError:contextInfo:), NULL);
			}];

			[videoDownloadTask resume];
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
