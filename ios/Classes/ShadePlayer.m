/*
 * This file is part of Sounds .
 *
 *   Sounds  is free software: you can redistribute it and/or modify
 *   it under the terms of the Lesser GNU General Public License
 *   version 3 (LGPL3) as published by the Free Software Foundation.
 *
 *   Sounds  is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details.
 *
 *   You should have received a copy of the Lesser GNU General Public License
 *   along with Sounds .  If not, see <https://www.gnu.org/licenses/>.
 */


/*
 * flauto is a sounds module.
 * Its purpose is to offer higher level functionnalities, using MediaService/MediaBrowser.
 * This module may use sounds module, but sounds module may not depends on this module.
 */

#import "ShadePlayer.h"
#import "Track.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>


/**
 * Plays an audio track using the OSs on UI (sometimes referred to as a Shade) media
 * player.
 * Allows playback control even when the phone is locked.
 */

static FlutterMethodChannel* _channel;

//---------------------------------------------------------------------------------------------


@implementation ShadePlayerManager
{
        //NSMutableArray* ShadePlayerSlots;
}
static ShadePlayerManager* shadePlayerManager; // Singleton



+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar
{
        _channel = [FlutterMethodChannel methodChannelWithName:@"com.bsutton.sounds.sounds_shade_player"
                                        binaryMessenger:[registrar messenger]];
        shadePlayerManager = [[ShadePlayerManager alloc] init]; // In super class
        [registrar addMethodCallDelegate:shadePlayerManager channel:_channel];
}

- (ShadePlayerManager*)init
{
        self = [super init];
        playerSlots = [[NSMutableArray alloc] init];
        return self;
}

extern void ShadePlayerReg(NSObject<FlutterPluginRegistrar>* registrar)
{
        [ShadePlayerManager registerWithRegistrar: registrar];
}

- (void)invokeCallback: (NSString*)methodName arguments: (NSDictionary*)call
{
        [_channel invokeMethod: methodName arguments: call ];
}


- (void)freeSlot: (int)slotNo
{
        playerSlots[slotNo] = [NSNull null];
}

- (SoundPlayerManager*)getManager
{
        return shadePlayerManager;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result
{
         int slotNo = [call.arguments[@"slotNo"] intValue];
               
        // The dart code supports lazy initialization of players.
        // This means that players can be registered (and slots allocated)
        // on the client side in a different order to which the players
        // are initialised.
        // As such we need to grow the slot array upto the 
        // requested slot no. even if we haven't seen initialisation
        // for the lower numbered slots.
        while ( slotNo >= [playerSlots count] )
        {
               [playerSlots addObject: [NSNull null]];
        }


        ShadePlayer* aShadePlayer = playerSlots[slotNo];
        
        if ([@"initializeMediaPlayer" isEqualToString:call.method])
        {
                 assert (playerSlots[slotNo] ==  [NSNull null] );
                 aShadePlayer = [[ShadePlayer alloc] init: slotNo];
                 playerSlots[slotNo] = aShadePlayer;

                 [aShadePlayer initializeShadePlayer: call result:result];
        } else
        
        if ([@"releaseMediaPlayer" isEqualToString:call.method])
        {
                [aShadePlayer releaseShadePlayer: call  result: result];
                playerSlots[slotNo] = [NSNull null];
                slotNo = -1;
                
        } else
        
        if ([@"startShadePlayer" isEqualToString:call.method])
        {
                 [aShadePlayer startShadePlayer: call result:result];
        } else

        {
                [super handleMethodCall: call  result: result];
        }
}


@end




//---------------------------------------------------------------------------------------------

@implementation ShadePlayer
{
       NSURL *audioFileURL;
       Track *track;
       id forwardTarget;
       id backwardTarget;
       id pauseTarget;
       t_SET_CATEGORY_DONE setCategoryDone;
       t_SET_CATEGORY_DONE setActiveDone;
       int slotNo;

}

- (ShadePlayer*)init: (int)aSlotNo
{
        slotNo = aSlotNo;
        return self;
}

- (void)initializeShadePlayer:(FlutterMethodCall *)call result:(FlutterResult)result
{
        setCategoryDone = NOT_SET;
        setActiveDone = NOT_SET;
        result([NSNumber numberWithBool: YES]);
}

- (void)releaseShadePlayer:(FlutterMethodCall *)call result:(FlutterResult)result
{
        // The code used to release all the media player resources is the same of the one needed
         // to stop the media playback. Then, use that one.
         // [self stopRecorder:result];
         [self stopPlayer];
         MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
         if (pauseTarget != nil)
         {
                 [commandCenter.togglePlayPauseCommand removeTarget: pauseTarget action: nil];
                 pauseTarget = nil;
         }
         if (forwardTarget != nil)
         {
                 [commandCenter.nextTrackCommand removeTarget: forwardTarget action: nil];
                 forwardTarget = nil;
         }

         if (backwardTarget != nil)
         {
                 [commandCenter.previousTrackCommand removeTarget: backwardTarget action: nil];
                 backwardTarget = nil;
         }

        [[self getPlugin] freeSlot: slotNo];
        result(@"The player has been successfully released");

}


- (SoundPlayerManager*) getPlugin
{
        return shadePlayerManager;
}


- (void)invokeCallback: (NSString*)methodName stringArg: (NSString*)stringArg
{
        NSDictionary* dic = @{ @"slotNo": [NSNumber numberWithInt: slotNo], @"arg": stringArg};
        [[self getPlugin] invokeCallback: methodName arguments: dic ];
}


- (void)invokeCallback: (NSString*)methodName boolArg: (Boolean)boolArg
{
        NSDictionary* dic = @{ @"slotNo": [NSNumber numberWithInt: slotNo], @"arg": [NSNumber numberWithBool: boolArg]};
        [[self getPlugin] invokeCallback: methodName arguments: dic ];
}


- (void)startShadePlayer:(FlutterMethodCall*)call result: (FlutterResult)result
{
         NSDictionary* trackDict = (NSDictionary*) call.arguments[@"track"];
         track = [[Track alloc] initFromDictionary:trackDict];
         BOOL canPause  = [call.arguments[@"canPause"] boolValue];
         BOOL canSkipForward = [call.arguments[@"canSkipForward"] boolValue];
         BOOL canSkipBackward = [call.arguments[@"canSkipBackward"] boolValue];


        if(!track)
        {
                result([FlutterError errorWithCode:@"UNAVAILABLE"
                                   message:@"The track passed to startPlayer is not valid."
                                   details:nil]);
        }


        // Check whether the audio file is stored as a path to a file or a buffer
        if([track isUsingPath])
        {
                // The audio file is stored as a path to a file

                NSString *path = track.path;

                bool isRemote = false;
                // Check whether a path was given
                if ([path class] == [NSNull class])
                {
                        // No path was given, get the path to a default sound
                        audioFileURL = [NSURL fileURLWithPath:[GetDirectoryOfType_Sounds(NSCachesDirectory) stringByAppendingString:@"sound.aac"]];
                // This file name is not good. Perhaps the MediaFormat is not AAC. !
                } else
                {
                        // A path was given, then create a NSURL with it
                        NSURL *remoteUrl = [NSURL URLWithString:path];

                        // Check whether the URL points to a local or remote file
                        if(remoteUrl && remoteUrl.scheme && remoteUrl.host)
                        {
                                audioFileURL = remoteUrl;
                                isRemote = true;
                        } else
                        {
                            audioFileURL = [[NSURL alloc] initFileURLWithPath:path isDirectory: NO];
                        }
                }

                // Able to play in silent mode
                if (setCategoryDone == NOT_SET)
                {
                        [[AVAudioSession sharedInstance]
                        setCategory: AVAudioSessionCategoryPlayback
                        error: nil];
                        setCategoryDone = FOR_PLAYING;
                }

                // Able to play in background
                if (setActiveDone == NOT_SET)
                {
                        [[AVAudioSession sharedInstance] setActive: YES error: nil];
                        setActiveDone = FOR_PLAYING;
                }

                isPaused = false;

                // Check whether the file path points to a remote or local file
                if (isRemote)
                {
                        NSURLSessionDataTask *downloadTask = [[NSURLSession sharedSession]
                                                  dataTaskWithURL:audioFileURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                      // The file to play has been downloaded, then initialize the audio player
                                                      // and start playing.

                                                      // We must create a new Audio Player instance to be able to play a different Url
                            self->audioPlayer = [[AVAudioPlayer alloc] initWithData:data error:nil];
                            self->audioPlayer.delegate = self;

                                dispatch_async(dispatch_get_main_queue(), ^{
                                                          [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
                                                      });

                            [self->audioPlayer play];
                                                   }];

                        [downloadTask resume];
                        [self startProgressTimer];
                        NSString *filePath = self->audioFileURL.absoluteString;
                        result(filePath);

                } else
                {
                        // Initialize the audio player with the file that the given path points to,
                        // and start playing.

                        // if (!audioPlayer) { // Fix sound distoring when playing recorded audio again.
                        audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:audioFileURL error:nil];
                        audioPlayer.delegate = self;
                        // }

                        // Able to play in silent mode
                        dispatch_async(dispatch_get_main_queue(),
                        ^{
                                [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
                        });

                        [audioPlayer play];
                        [self startProgressTimer];
                        NSString *filePath = audioFileURL.absoluteString;
                        result(filePath);
                }
        } else
        {
        // The audio file is stored as a buffer
                FlutterStandardTypedData* dataBuffer = (FlutterStandardTypedData*) track.dataBuffer;
                NSData* bufferData = [dataBuffer data];
                audioPlayer = [[AVAudioPlayer alloc] initWithData: bufferData error: nil];
                audioPlayer.delegate = self;
                dispatch_async(dispatch_get_main_queue(),
                ^{
                        [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
                });
                [audioPlayer play];
                [self startProgressTimer];
                result(@"Playing from buffer");
        }
        //[ self invokeCallback:@"updatePlaybackState" arguments:playingState];

        // Display the notification with the media controls
        [self setupRemoteCommandCenter:canPause canSkipForward:canSkipForward   canSkipBackward:canSkipBackward result:result];
        [self setupNowPlaying];

}

// Give the system information about what the audio player
// is currently playing. Takes in the image to display in the
// notification to control the media playback.
- (void)setupNowPlaying
{
        // Initialize the MPNowPlayingInfoCenter

        MPNowPlayingInfoCenter *playingInfoCenter = [MPNowPlayingInfoCenter defaultCenter];
        NSMutableDictionary *songInfo = [[NSMutableDictionary alloc] init];
        // The caller specify an asset to be used.
        // Probably good in the future to allow the caller to specify the image itself, and not a resource.
        if ((track.albumArtUrl != nil) && ([track.albumArtUrl class] != [NSNull class])   )         // The albumArt is accessed in a URL
        {
                // Retrieve the album art for the
                // current track .
                NSURL *url = [NSURL URLWithString:self->track.albumArtUrl];
                UIImage *artworkImage = [UIImage imageWithData:[NSData dataWithContentsOfURL:url]];
                if(artworkImage)
                {
			MPMediaItemArtwork * albumArt = [[MPMediaItemArtwork alloc] initWithBoundsSize:artworkImage.size 
				requestHandler:^UIImage * _Nonnull(CGSize size) {
				return artworkImage;
			}];

                        [songInfo setObject:albumArt forKey:MPMediaItemPropertyArtwork];
                }
        } else
        if ((track.albumArtAsset) && ([track.albumArtAsset class] != [NSNull class])   )        // The albumArt is an Asset
        {
                UIImage* artworkImage = [UIImage imageNamed: track.albumArtAsset];
                if (artworkImage != nil)
                {
			MPMediaItemArtwork * albumArt = [[MPMediaItemArtwork alloc] initWithBoundsSize:artworkImage.size 
				requestHandler:^UIImage * _Nonnull(CGSize size) {
				return artworkImage;
			}];
                    
                        [songInfo setObject:albumArt forKey: MPMediaItemPropertyArtwork];
                }
        } else
        if ((track.albumArtFile) && ([track.albumArtFile class] != [NSNull class])   )          //  The AlbumArt is a File
        {
                UIImage* artworkImage = [UIImage imageWithContentsOfFile: track.albumArtFile];
                if (artworkImage != nil)
                {
			MPMediaItemArtwork * albumArt = [[MPMediaItemArtwork alloc] initWithBoundsSize:artworkImage.size 
				requestHandler:^UIImage * _Nonnull(CGSize size) {
				return artworkImage;
			}];
                        [songInfo setObject:albumArt forKey: MPMediaItemPropertyArtwork];
                }
        } else // Nothing specified. We try to use the App Icon
        {
                UIImage* artworkImage = [UIImage imageNamed: @"AppIcon"];
                if (artworkImage != nil)
                {
			MPMediaItemArtwork * albumArt = [[MPMediaItemArtwork alloc] initWithBoundsSize:artworkImage.size 
				requestHandler:^UIImage * _Nonnull(CGSize size) {
				return artworkImage;
			}];
                        [songInfo setObject:albumArt forKey: MPMediaItemPropertyArtwork];
                }
        }

        NSNumber *progress = [NSNumber numberWithDouble: audioPlayer.currentTime];
        NSNumber *duration = [NSNumber numberWithDouble: audioPlayer.duration];

        [songInfo setObject:track.title forKey:MPMediaItemPropertyTitle];
        [songInfo setObject:track.artist forKey:MPMediaItemPropertyArtist];
        [songInfo setObject:progress forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
        [songInfo setObject:duration forKey:MPMediaItemPropertyPlaybackDuration];
        bool b = [audioPlayer isPlaying];
        [songInfo setObject:[NSNumber numberWithDouble:(b ? 1.0f : 0.0f)] forKey:MPNowPlayingInfoPropertyPlaybackRate];

        [playingInfoCenter setNowPlayingInfo:songInfo];
}


- (void)cleanTarget:(BOOL)canPause canSkipForward:(BOOL)canSkipForward  canSkipBackward:(BOOL)canSkipBackward
{
          // [commandCenter.playCommand setEnabled:YES];
          // [commandCenter.pauseCommand setEnabled:YES];
          //   [commandCenter.playCommand addTargetWithHandler: ^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
          //       // [[MediaController sharedInstance] playOrPauseMusic];    // Begin playing the current track.
          //       [self resumePlayer:result];
          //       return MPRemoteCommandHandlerStatusSuccess;
          //   }];
          //
          //   [commandCenter.pauseCommand addTargetWithHandler: ^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
          //       // [[MediaController sharedInstance] playOrPauseMusic];    // Begin playing the current track.
          //       [self pausePlayer:result];
          //       return MPRemoteCommandHandlerStatusSuccess;
          //   }];
          MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];

          if (pauseTarget != nil)
          {
                [commandCenter.togglePlayPauseCommand removeTarget: pauseTarget action: nil];
                pauseTarget = nil;
          }
          if (forwardTarget != nil)
          {
                [commandCenter.nextTrackCommand removeTarget: forwardTarget action: nil];
                forwardTarget = nil;
          }

          if (backwardTarget != nil)
          {
                [commandCenter.previousTrackCommand removeTarget: backwardTarget action: nil];
                backwardTarget = nil;
          }
          [commandCenter.togglePlayPauseCommand setEnabled: true]; // If the caller does not want to control pause button, we will use our default action
          [commandCenter.nextTrackCommand setEnabled:canSkipForward];
          [commandCenter.previousTrackCommand setEnabled:canSkipBackward];

          {
                pauseTarget = [commandCenter.togglePlayPauseCommand addTargetWithHandler: ^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event)
                {
                    
                    bool b = [self->audioPlayer isPlaying];
                        // If the caller wants to control the pause button, just call him
                        if (b)
                        {
                                if (canPause)
                                        [self invokeCallback:@"pause" boolArg:true];
                                else
                                        [self pause];
                        } else
                        {
                                if (canPause)
                                        [self invokeCallback:@"resume" boolArg:true];
                                else
                                        [self resume];
                        }
                        return MPRemoteCommandHandlerStatusSuccess;
                }];
        }

        if (canSkipForward)
        {
                forwardTarget = [commandCenter.nextTrackCommand addTargetWithHandler: ^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event)
                {
                        [self invokeCallback:@"skipForward" stringArg:@""];
                        // [[MediaController sharedInstance] fastForward];    // forward to next track.
                        return MPRemoteCommandHandlerStatusSuccess;
                }];
        }

        if (canSkipBackward)
        {
                backwardTarget = [commandCenter.previousTrackCommand addTargetWithHandler: ^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event)
                {
                        [self invokeCallback:@"skipBackward" stringArg:@""];
                        // [[MediaController sharedInstance] rewind];    // back to previous track.
                        return MPRemoteCommandHandlerStatusSuccess;
                }];
        }
}


- (void)stopPlayer
{
          [self stopProgressTimer];
          isPaused = false;
          if (audioPlayer)
          {
                [audioPlayer stop];
                //audioPlayer = nil;
          }
          // ????  [self cleanTarget:false canSkipForward:false canSkipBackward:false];
          if ( (setActiveDone != BY_USER) && (setActiveDone != NOT_SET) )
          {
                [self cleanTarget:false canSkipForward:false canSkipBackward:false]; // ???
                [[AVAudioSession sharedInstance] setActive: NO error: nil];
                setActiveDone = NOT_SET;
          }
}



// Give the system information about what to do when the notification
// control buttons are pressed.
- (void)setupRemoteCommandCenter:(BOOL)canPause canSkipForward:(BOOL)canSkipForward canSkipBackward:(BOOL)canSkipBackward result: (FlutterResult)result
{
        [self cleanTarget:canPause canSkipForward:canSkipForward canSkipBackward:canSkipBackward];
}


// post fix with _Sound to avoid conflicts with common libs including path_provider
static NSString* GetDirectoryOfType_Sounds(NSSearchPathDirectory dir)
{
        NSArray* paths = NSSearchPathForDirectoriesInDomains(dir, NSUserDomainMask, YES);
        return [paths.firstObject stringByAppendingString:@"/"];
}

@end
