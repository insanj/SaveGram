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

			UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
			NSLog(@"[SaveGram] Finished saving photo (%@) to photo library!", image);
		}

		else {
			NSURL *videoURL = [post videoURLForVideoVersion:[%c(IGPost) fullSizeVideoVersionForDevice]];
			// NSString *videoPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"/Documents/SaveGram/"];
			NSString *videoPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/SaveGram"];
			NSString *videoFilePath = [videoPath stringByAppendingString:@"/movie"];
			NSFileManager *manager = [NSFileManager defaultManager];

			NSError __block *videoError;
		    [manager createDirectoryAtPath:videoPath withIntermediateDirectories:YES attributes:nil error:&videoError];
			BOOL wrote = [[NSData dataWithContentsOfURL:videoURL] writeToFile:videoFilePath atomically:YES];

			UISaveVideoAtPathToSavedPhotosAlbum(videoFilePath, nil, nil, nil);
			if (videoError) {
				NSLog(@"[SaveGram] %@ failed to save video (from %@) to photo library: %@", wrote ? @"Happily" : @"Terribly", videoFilePath, videoError);
			}

			else {
				NSLog(@"[SaveGram] %@ saved video to photo library!", wrote ? @"Happily" : @"Terribly");
			}

			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
				BOOL unwrote = [manager removeItemAtPath:videoPath error:&videoError];
				if (videoError) {
					NSLog(@"[SaveGram] %@ failed to delete video from %@: %@", unwrote ? @"Happily" : @"Terribly", videoPath, videoError);
				}

				else {
					NSLog(@"[SaveGram] %@ deleted video from temporary save location!", unwrote ? @"Happily" : @"Terribly");
				}
			});
		}
	}

	else {
		%orig(title);
	}
}

%end
