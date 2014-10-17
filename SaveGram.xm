 #import "SaveGram.h"

#define SGLOG(fmt, ...) NSLog((@"[SaveGram] %s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)

static ALAssetsLibrary *kSaveGramAssetsLibrary = [[ALAssetsLibrary alloc] init];
static ALAssetsGroup *kSaveGramAssetsGroup;
static NSString *kSaveGramAlbumName = @"Saved from Instagram";

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
			NSLog(@"[SaveGram] Detected dismissal of action sheet with Save option, trying to save %@...", post);

			if (post.mediaType == 1) {
				NSURL *imageURL =[post imageURLForFullSizeImage];
				UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:imageURL]];

				UIImageWriteToSavedPhotosAlbum(image, nil, NULL, NULL);
				NSLog(@"[SaveGram] Finished saving photo (%@) to photo library.", image);
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
		NSLog(@"[SaveGram] Couldn't save video to photo library: %@", error);
		return;
	}

	[[NSFileManager defaultManager] removeItemAtPath:videoPath error:&error];
	if (error) {
		NSLog(@"[SaveGram] Couldn't remove video from temporary location: %@", error);
		return;
	}

	NSLog(@"[SaveGram] Finished saving video to photo library.");
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

@interface IGFeedItemActionCell (SaveGram)

// - (void)savegram_makeSurePhotosAlbumWithNameExists:(NSString *)albumName;
// - (void)savegram_createPhotosAlbumWithName:(NSString *)albumName;
- (void)savegram_saveImageData:(NSData *)imageData toPhotosAlbumWithName:(NSString *)albumName;
- (void)savegram_saveVideoAtPath:(NSString *)videoPath toPhotosAlbumWithName:(NSString *)albumName;

@end

%group ThirdSupportPhase

%hook IGActionSheet

/*- (void)setButtons:(id)arg1 {
	NSArray *actionSheetButtons = arg1;
	%orig([actionSheetButtons arrayByAddingObject:[]])
}*/

 - (void)show {
	[self addButtonWithTitle:@"Save" style:0];
	%orig();
}

%end

%hook IGFeedItemActionCell

- (void)actionSheetDismissedWithButtonTitled:(NSString *)title {
	if ([title isEqualToString:@"Save"]) {
		// Instead of opting for intelligent version checking when launching Instagram
		// (ala SlickGram), this segment uses try/catches to prevent crashing and only
		// notify the user when things /actually/ aren't working.
		@try {
			IGFeedItem *post = self.feedItem;
			SGLOG(@"Detected dismissal of action sheet with Save option, trying to save %@...", post);

			if (post.mediaType == 1) {
				NSURL *imageURL = [post imageURLForFullSizeImage];
				[self savegram_saveImageData:[NSData dataWithContentsOfURL:imageURL] toPhotosAlbumWithName:kSaveGramAlbumName];
			}

			else {
				NSInteger videoVersion = [%c(IGPost) videoVersionForCurrentNetworkConditions];

				NSURL *videoURL =  [post videoURLForVideoVersion:videoVersion];
				NSURLSessionTask *videoDownloadTask = [[NSURLSession sharedSession] downloadTaskWithURL:videoURL completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
					NSFileManager *fileManager = [NSFileManager defaultManager];
				    NSURL *videoDocumentsURL = [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
				    NSURL *videoSavedURL = [videoDocumentsURL URLByAppendingPathComponent:[videoURL lastPathComponent]];
				    [fileManager moveItemAtURL:location toURL:videoSavedURL error:&error];

				    [self savegram_saveVideoAtPath:videoSavedURL.path toPhotosAlbumWithName:kSaveGramAlbumName];
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

static inline void savegram_makeSurePhotosAlbumWithNameExists(NSString *albumName) {
	// Check if Photos album exists
	[kSaveGramAssetsLibrary enumerateGroupsWithTypes:ALAssetsGroupAlbum usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
      if ([[group valueForProperty:ALAssetsGroupPropertyName] isEqualToString:albumName]) {
      	kSaveGramAssetsGroup = group;
      }
	} failureBlock:^(NSError* error) {
		SGLOG(@"Couldn't enumerate Photos albums (%@): %@", kSaveGramAssetsLibrary, [error localizedDescription]);
	}];

	// If not, create it with given name
	[kSaveGramAssetsLibrary addAssetsGroupAlbumWithName:albumName resultBlock:^(ALAssetsGroup *group) {
		SGLOG(@"Created asset album with name %@", albumName);
	} failureBlock:^(NSError *error) {
		if (error && error.code != 0) {
			SGLOG(@"Couldn't create assets album (%@): %@ ", kSaveGramAssetsLibrary, [error localizedDescription]);
		}
	}];
}

%new - (void)savegram_saveImageData:(NSData *)imageData toPhotosAlbumWithName:(NSString *)albumName {
	savegram_makeSurePhotosAlbumWithNameExists(albumName);

	// Save Image (from imageData) to assets album, then to Photos album
	[kSaveGramAssetsLibrary writeImageDataToSavedPhotosAlbum:imageData metadata:nil completionBlock:^(NSURL *assetURL, NSError *error) {
		if (error && error.code != 0) {
			SGLOG(@"Couldn't save image to Photos albums (%@): %@", kSaveGramAssetsLibrary, [error localizedDescription]);
		}

		else {
			[kSaveGramAssetsLibrary assetForURL:assetURL resultBlock:^(ALAsset *asset) {
				[kSaveGramAssetsGroup addAsset:asset];
				SGLOG(@"Saved image asset (%@) to Photos album (%@)", [[asset defaultRepresentation] filename], albumName);
			} failureBlock:^(NSError* error) {
				SGLOG(@"Couldn't enumerate Photos albums (%@): %@", kSaveGramAssetsLibrary, [error localizedDescription]);
			}];
		}
	}];
}

%new  - (void)savegram_saveVideoAtPath:(NSURL *)videoPath toPhotosAlbumWithName:(NSString *)albumName {
	savegram_makeSurePhotosAlbumWithNameExists(albumName);

	// Save Video (at videoPath) to assets album, then to Photos album
	[kSaveGramAssetsLibrary writeVideoAtPathToSavedPhotosAlbum:videoPath completionBlock:^(NSURL *assetURL, NSError *error) {
		if (error && error.code != 0) {
			SGLOG(@"Couldn't save video to Photos albums (%@): %@", kSaveGramAssetsLibrary, [error localizedDescription]);
		}

		else {
			[kSaveGramAssetsLibrary assetForURL:assetURL resultBlock:^(ALAsset *asset) {
				[kSaveGramAssetsGroup addAsset:asset];
				SGLOG(@"Saved video asset (%@) to Photos album (%@)", [[asset defaultRepresentation] filename], albumName);

				NSError *removeItemError;
				[[NSFileManager defaultManager] removeItemAtPath:[videoPath path] error:&removeItemError];
			} failureBlock:^(NSError* error) {
				SGLOG(@"Couldn't enumerate Photos albums (%@): %@", kSaveGramAssetsLibrary, [error localizedDescription]);

				NSError *removeItemError;
				[[NSFileManager defaultManager] removeItemAtPath:[videoPath path] error:&removeItemError];
			}];
		}
	}];
}

%end

%end // %group ThirdupportPhase

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
		NSLog(@"[SaveGram] Detected Instagram running on supported old version %@.", version);
		%init(FirstSupportPhase);
	}

	else if (supportedVersionComparisonResult == NSOrderedSame) {
		NSLog(@"[SaveGram] Detected Instagram running on supported version %@.", version);
		%init(SecondSupportPhase);
	}

	else {
		NSLog(@"[SaveGram] Detected Instagram running on newest supported version %@.", version);
		%init(ThirdSupportPhase);
	}
}
