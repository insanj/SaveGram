#import "SaveGram.h"

#define SGLOG(fmt, ...) NSLog((@"[SaveGram] %s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)

/* 
lllllll                                                                                                      
l:::::l                                                                                                      
l:::::l                                                                                                      
l:::::l                                                                                                      
 l::::l     eeeeeeeeeeee       ggggggggg   ggggg aaaaaaaaaaaaa      ccccccccccccccccyyyyyyy           yyyyyyy
 l::::l   ee::::::::::::ee    g:::::::::ggg::::g a::::::::::::a   cc:::::::::::::::c y:::::y         y:::::y 
 l::::l  e::::::eeeee:::::ee g:::::::::::::::::g aaaaaaaaa:::::a c:::::::::::::::::c  y:::::y       y:::::y  
 l::::l e::::::e     e:::::eg::::::ggggg::::::gg          a::::ac:::::::cccccc:::::c   y:::::y     y:::::y   
 l::::l e:::::::eeeee::::::eg:::::g     g:::::g    aaaaaaa:::::ac::::::c     ccccccc    y:::::y   y:::::y    
 l::::l e:::::::::::::::::e g:::::g     g:::::g  aa::::::::::::ac:::::c                  y:::::y y:::::y     
 l::::l e::::::eeeeeeeeeee  g:::::g     g:::::g a::::aaaa::::::ac:::::c                   y:::::y:::::y      
 l::::l e:::::::e           g::::::g    g:::::ga::::a    a:::::ac::::::c     ccccccc       y:::::::::y       
l::::::le::::::::e          g:::::::ggggg:::::ga::::a    a:::::ac:::::::cccccc:::::c        y:::::::y        
l::::::l e::::::::eeeeeeee   g::::::::::::::::ga:::::aaaa::::::a c:::::::::::::::::c         y:::::y         
l::::::l  ee:::::::::::::e    gg::::::::::::::g a::::::::::aa:::a cc:::::::::::::::c        y:::::y          
llllllll    eeeeeeeeeeeeee      gggggggg::::::g  aaaaaaaaaa  aaaa   cccccccccccccccc       y:::::y           
                                        g:::::g                                           y:::::y            
                            gggggg      g:::::g                                          y:::::y             
                            g:::::gg   gg:::::g                                         y:::::y              
                             g::::::ggg:::::::g                                        y:::::y               
                              gg:::::::::::::g                                        yyyyyyy                
                                ggg::::::ggg                                                                 
                                   gggggg                                                                                             
*/

%group FirstSupportPhase

%hook IGActionSheet

// Not sure if the IGActionSheet is used in any case besides image/video options,
// but if it was, the .topMostViewController or .delegate properties might be nice
- (void)showWithTitle:(NSString *)title {
	SGLOG(@"Detected action sheet from item, adding save option...");
	
	[self addButtonWithTitle:@"Save" style:0];
	%orig(title);
}

%end


%hook IGFeedItemActionCell

- (void)actionSheetDismissedWithButtonTitled:(NSString *)title {
	if ([title isEqualToString:@"Save"]) {
		// Instead of opting for intelligent version checking when launching Instagram
		// (ala SlickGram), this segment uses try/catches to prevent crashing and only
		// notify the user when things /actually/ aren't working.
		@try{
			IGFeedItem *post = self.feedItem;
			SGLOG(@"Detected dismissal of action sheet with Save option, trying to save %@...", post);

			if (post.mediaType == 1) {
				NSURL *imageURL = [post imageURLForImageVersion:[%c(IGPost) fullSizeImageVersionForDevice]];
				UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:imageURL]];

				UIImageWriteToSavedPhotosAlbum(image, nil, NULL, NULL);
				SGLOG(@"Finished saving photo (%@) to photo library.", image);
			}

			else {
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
			UIAlertView *errorView = [[UIAlertView alloc] initWithTitle:@"Oops!" message:[NSString stringWithFormat:@"Looks like SaveGram had trouble saving this post. Please send the following error message to @insanj: %@", e.reason] delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil];
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
		SGLOG(@"Couldn't save video to photo library: %@", [error localizedDescription]);
		return;
	}

	[[NSFileManager defaultManager] removeItemAtPath:videoPath error:&error];
	if (error) {
		SGLOG(@"Couldn't remove video from temporary location: %@", [error localizedDescription]);
		return;
	}

	SGLOG(@"Finished saving video to photo library.");
}

%end

%end // %group FirstSupportPhase

%group SecondSupportPhase

%hook IGActionSheet

+ (void)showWithDelegate:(id)arg1 {
	[self addButtonWithTitle:@"Save" style:0];
	%orig(arg1);
}

+ (void)showWithCallback:(id)arg1 {
	[self addButtonWithTitle:@"Save" style:0];
	%orig(arg1);
}

%end

%hook IGFeedItemActionCell

- (void)actionSheetDismissedWithButtonTitled:(NSString *)title {
	if ([title isEqualToString:@"Save"]) {
		// Instead of opting for intelligent version checking when launching Instagram
		// (ala SlickGram), this segment uses try/catches to prevent crashing and only
		// notify the user when things /actually/ aren't working.
		@try{
			IGFeedItem *post = self.feedItem;
			SGLOG(@"Detected dismissal of action sheet with Save option, trying to save %@...", post);

			if (post.mediaType == 1) {
				NSURL *imageURL = [post imageURLForFullSizeImage];
				UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:imageURL]];

				UIImageWriteToSavedPhotosAlbum(image, nil, NULL, NULL);
				SGLOG(@"Finished saving photo (%@) to photo library.", image);
			}

			else {
				NSInteger videoVersion = [%c(IGPost) videoVersionForCurrentNetworkConditions];

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
		SGLOG(@"Couldn't save video to photo library: %@", error);
		return;
	}

	[[NSFileManager defaultManager] removeItemAtPath:videoPath error:&error];
	if (error) {
		SGLOG(@"Couldn't remove video from temporary location: %@", error);
		return;
	}

	SGLOG(@"Finished saving video to photo library.");
}

%end

%end // %group SecondSupportPhase

/*                                                                                                                                                                                                                                                                    
                                                                                                                            tttt          
                                                                                                                         ttt:::t          
                                                                                                                         t:::::t          
                                                                                                                         t:::::t          
    ccccccccccccccccuuuuuu    uuuuuu rrrrr   rrrrrrrrr   rrrrr   rrrrrrrrr       eeeeeeeeeeee    nnnn  nnnnnnnn    ttttttt:::::ttttttt    
  cc:::::::::::::::cu::::u    u::::u r::::rrr:::::::::r  r::::rrr:::::::::r    ee::::::::::::ee  n:::nn::::::::nn  t:::::::::::::::::t    
 c:::::::::::::::::cu::::u    u::::u r:::::::::::::::::r r:::::::::::::::::r  e::::::eeeee:::::een::::::::::::::nn t:::::::::::::::::t    
c:::::::cccccc:::::cu::::u    u::::u rr::::::rrrrr::::::rrr::::::rrrrr::::::re::::::e     e:::::enn:::::::::::::::ntttttt:::::::tttttt    
c::::::c     cccccccu::::u    u::::u  r:::::r     r:::::r r:::::r     r:::::re:::::::eeeee::::::e  n:::::nnnn:::::n      t:::::t          
c:::::c             u::::u    u::::u  r:::::r     rrrrrrr r:::::r     rrrrrrre:::::::::::::::::e   n::::n    n::::n      t:::::t          
c:::::c             u::::u    u::::u  r:::::r             r:::::r            e::::::eeeeeeeeeee    n::::n    n::::n      t:::::t          
c::::::c     cccccccu:::::uuuu:::::u  r:::::r             r:::::r            e:::::::e             n::::n    n::::n      t:::::t    tttttt
c:::::::cccccc:::::cu:::::::::::::::uur:::::r             r:::::r            e::::::::e            n::::n    n::::n      t::::::tttt:::::t
 c:::::::::::::::::c u:::::::::::::::ur:::::r             r:::::r             e::::::::eeeeeeee    n::::n    n::::n      tt::::::::::::::t
  cc:::::::::::::::c  uu::::::::uu:::ur:::::r             r:::::r              ee:::::::::::::e    n::::n    n::::n        tt:::::::::::tt
    cccccccccccccccc    uuuuuuuu  uuuurrrrrrr             rrrrrrr                eeeeeeeeeeeeee    nnnnnn    nnnnnn          ttttttttttt  
 */

%group ThirdSupportPhase

static ALAssetsLibrary *kSaveGramAssetsLibrary = [[ALAssetsLibrary alloc] init];

%hook IGActionSheet

 - (void)show {
	[self addButtonWithTitle:@"Save" style:0];
	%orig();
}

%end

%hook IGFeedItemActionCell

- (void)actionSheetDismissedWithButtonTitled:(NSString *)title {
	if ([title isEqualToString:@"Save"]) {
		IGFeedItem *post = self.feedItem;
		SGLOG(@"Detected dismissal of action sheet with Save option, trying to save %@...", post);

		if (post.mediaType == 1) {
			NSURL *postImageURL;
			if ([post respondsToSelector:@selector(imageURLForFullSizeImage)]) {
				postImageURL = [post imageURLForFullSizeImage];
			}

			else {
				postImageURL = [post imageURLForImageIndex:0]; // in 6.1.5 all URL methods require a size, it seems that this set of images begins with the largest, and progress to smaller dimensions from the 0th index
			}

			UIImage *postImage = [UIImage imageWithData:[NSData dataWithContentsOfURL:postImageURL]];

			IGAssetWriter *postImageAssetWriter = [[%c(IGAssetWriter) alloc] initWithImage:postImage metadata:nil];
			[postImageAssetWriter writeToInstagramAlbum];
		}

		else {
			NSInteger videoVersion = [%c(IGPost) videoVersionForCurrentNetworkConditions];

			NSURL *videoURL =  [post videoURLForVideoVersion:videoVersion];
			NSURLSessionTask *videoDownloadTask = [[NSURLSession sharedSession] downloadTaskWithURL:videoURL completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
				NSFileManager *fileManager = [NSFileManager defaultManager];
			    NSURL *videoDocumentsURL = [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
			    NSURL *videoSavedURL = [videoDocumentsURL URLByAppendingPathComponent:[videoURL lastPathComponent]];
			    [fileManager moveItemAtURL:location toURL:videoSavedURL error:&error];

			    [%c(IGAssetWriter) writeVideoToInstagramAlbum:videoSavedURL completionBlock:nil];
			}];

			[videoDownloadTask resume];
		}
	}

	else {
		%orig(title);
	}
}

%end

%end // %group ThirdSupportPhase

/*                                                                                                     
                                                                                                         dddddddd
                hhhhhhh                                                                                  d::::::d
                h:::::h                                                                                  d::::::d
                h:::::h                                                                                  d::::::d
                h:::::h                                                                                  d:::::d 
    ssssssssss   h::::h hhhhh         aaaaaaaaaaaaa  rrrrr   rrrrrrrrr       eeeeeeeeeeee        ddddddddd:::::d 
  ss::::::::::s  h::::hh:::::hhh      a::::::::::::a r::::rrr:::::::::r    ee::::::::::::ee    dd::::::::::::::d 
ss:::::::::::::s h::::::::::::::hh    aaaaaaaaa:::::ar:::::::::::::::::r  e::::::eeeee:::::ee d::::::::::::::::d 
s::::::ssss:::::sh:::::::hhh::::::h            a::::arr::::::rrrrr::::::re::::::e     e:::::ed:::::::ddddd:::::d 
 s:::::s  ssssss h::::::h   h::::::h    aaaaaaa:::::a r:::::r     r:::::re:::::::eeeee::::::ed::::::d    d:::::d 
   s::::::s      h:::::h     h:::::h  aa::::::::::::a r:::::r     rrrrrrre:::::::::::::::::e d:::::d     d:::::d 
      s::::::s   h:::::h     h:::::h a::::aaaa::::::a r:::::r            e::::::eeeeeeeeeee  d:::::d     d:::::d 
ssssss   s:::::s h:::::h     h:::::ha::::a    a:::::a r:::::r            e:::::::e           d:::::d     d:::::d 
s:::::ssss::::::sh:::::h     h:::::ha::::a    a:::::a r:::::r            e::::::::e          d::::::ddddd::::::dd
s::::::::::::::s h:::::h     h:::::ha:::::aaaa::::::a r:::::r             e::::::::eeeeeeee   d:::::::::::::::::d
 s:::::::::::ss  h:::::h     h:::::h a::::::::::aa:::ar:::::r              ee:::::::::::::e    d:::::::::ddd::::d
  sssssssssss    hhhhhhh     hhhhhhh  aaaaaaaaaa  aaaarrrrrrr                eeeeeeeeeeeeee     ddddddddd   ddddd
*/     

%ctor {
	NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
	NSComparisonResult supportedVersionComparisonResult = [version compare:@"6.1.2" options:NSNumericSearch];

	if (supportedVersionComparisonResult == NSOrderedDescending) {
		SGLOG(@"Detected Instagram running on newest supported version %@.", version);
		%init(ThirdSupportPhase);
	}

	else if (supportedVersionComparisonResult == NSOrderedSame) {
		SGLOG(@"Detected Instagram running on supported version %@.", version);
		%init(SecondSupportPhase);
	}

	else {
		SGLOG(@"Detected Instagram running on supported old version %@.", version);
		%init(FirstSupportPhase);
	}
}
