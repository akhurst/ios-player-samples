//
//  ViewController.m
//  VideoCloudBasicPlayer
//
//  Copyright © 2020 Brightcove, Inc. All rights reserved.
//

#import "ViewController.h"
#import "NowPlayingHandler.h"

@import BrightcovePlayerSDK;

// ** Customize these values with your own account information **
static NSString * const kViewControllerPlaybackServicePolicyKey = @"BCpkADawqM2g20ETofxJDhAFvPG1VmaH518NJcDxe9hot9kRYZuetXbFd68kL9SxRISaxAifI8OpG_5k8Fhpo-JVrxa1Tru0P1w5MbPRhXpeEEF8HdRQWJpVmPNT0PUkKlF-kTanqnTf2NHA";
static NSString * const kViewControllerAccountID = @"6250470670001";
static NSString * const kViewControllerVideoID = @"6263986007001";


@interface ViewController () <BCOVPlaybackControllerDelegate, BCOVPUIPlayerViewDelegate>

@property (nonatomic, strong) BCOVPlaybackService *playbackService;
@property (nonatomic, strong) id<BCOVPlaybackController> playbackController;
@property (nonatomic) BCOVPUIPlayerView *playerView;
@property (nonatomic, weak) IBOutlet UIView *videoContainer;
@property (nonatomic, weak) IBOutlet UIButton *muteButton;
@property (nonatomic, strong) NowPlayingHandler *nowPlayingHandler;
@property (nonatomic, weak) AVPlayer *currentPlayer;

@end


@implementation ViewController

#pragma mark Setup Methods

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self)
    {
        [self setup];
    }
    return self;
}

- (void)setup
{
    @try
      {
        [BCOVGlobalConfiguration.sharedConfig setValue:@{
          @"privateUser": @"allenhurst+5@gmail.com",
          @"privateApplication": @""
        }
        forKey:@"privateSessionAnalytics"];
      }
      @catch (NSException *e)
      {
        NSLog(@"%@", e.description);
      }
    _playbackController = [BCOVPlayerSDKManager.sharedManager createPlaybackController];

    _playbackController.delegate = self;
    _playbackController.allowsExternalPlayback = YES;
    _playbackController.allowsBackgroundAudioPlayback = YES;
    _playbackController.autoPlay = YES;

    _playbackService = [[BCOVPlaybackService alloc] initWithAccountId:kViewControllerAccountID
                                                            policyKey:kViewControllerPlaybackServicePolicyKey];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setUpAudioSession];

    // Set up our player view. Create with a standard VOD layout.
    BCOVPUIPlayerViewOptions *options = [BCOVPUIPlayerViewOptions new];
    options.showPictureInPictureButton = YES;
    
    BCOVPUIPlayerView *playerView = [[BCOVPUIPlayerView alloc] initWithPlaybackController:self.playbackController options:options controlsView:[BCOVPUIBasicControlView basicControlViewWithVODLayout] ];
    playerView.delegate = self;

    [_videoContainer addSubview:playerView];
    playerView.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
                                              [playerView.topAnchor constraintEqualToAnchor:_videoContainer.topAnchor],
                                              [playerView.rightAnchor constraintEqualToAnchor:_videoContainer.rightAnchor],
                                              [playerView.leftAnchor constraintEqualToAnchor:_videoContainer.leftAnchor],
                                              [playerView.bottomAnchor constraintEqualToAnchor:_videoContainer.bottomAnchor],
                                              ]];
    _playerView = playerView;

    // Associate the playerView with the playback controller.
    _playerView.playbackController = _playbackController;
    
    _nowPlayingHandler = [[NowPlayingHandler alloc] initWithPlaybackController:_playbackController];

    [self requestContentFromPlaybackService];
}

- (void)setUpAudioSession
{
    NSError *categoryError = nil;
    BOOL success;
    
    // If the player is muted, then allow mixing.
    // Ensure other apps can have their background audio
    // active when this app is in foreground
    if (self.currentPlayer.isMuted)
    {
        success = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionMixWithOthers error:&categoryError];
    }
    else
    {
        success = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback withOptions:0 error:&categoryError];
    }
    
    if (!success)
    {
        NSLog(@"AppDelegate Debug - Error setting AVAudioSession category.  Because of this, there may be no sound. `%@`", categoryError);
    }
}

- (IBAction)muteButtonPressed:(id)sender
{
    if (!self.currentPlayer)
    {
        return;
    }
    
    if (self.currentPlayer.isMuted)
    {
        [self.muteButton setTitle:@"Mute AVPlayer" forState:UIControlStateNormal];
    }
    else
    {
        [self.muteButton setTitle:@"Unmute AVPlayer" forState:UIControlStateNormal];
    }
    
    self.currentPlayer.muted = !self.currentPlayer.isMuted;
    
    [self setUpAudioSession];
}

- (void)requestContentFromPlaybackService
{
    [self.playbackService findVideoWithVideoID:kViewControllerVideoID parameters:nil completion:^(BCOVVideo *video, NSDictionary *jsonResponse, NSError *error) {
        
        if (video)
        {
            [self.playbackController setVideos:@[ video ]];
        }
        else
        {
            NSLog(@"ViewController Debug - Error retrieving video playlist: `%@`", error);
        }

    }];
}

#pragma mark - BCOVPlaybackControllerDelegate

- (void)playbackController:(id<BCOVPlaybackController>)controller didAdvanceToPlaybackSession:(id<BCOVPlaybackSession>)session
{
    NSLog(@"Advanced to new session.");
    
    self.currentPlayer = session.player;
    
    // Enable route detection for AirPlay
    // https://developer.apple.com/documentation/avfoundation/avroutedetector/2915762-routedetectionenabled
    self.playerView.controlsView.routeDetector.routeDetectionEnabled = YES;
}

- (void)playbackController:(id<BCOVPlaybackController>)controller playbackSession:(id<BCOVPlaybackSession>)session didProgressTo:(NSTimeInterval)progress
{
    NSLog(@"Progress: %0.2f seconds", progress);
}

- (void)playbackController:(id<BCOVPlaybackController>)controller playbackSession:(id<BCOVPlaybackSession>)session didReceiveLifecycleEvent:(BCOVPlaybackSessionLifecycleEvent *)lifecycleEvent
{
    if ([lifecycleEvent.eventType isEqualToString:kBCOVPlaybackSessionLifecycleEventEnd])
    {
        // Disable route detection for AirPlay
        // https://developer.apple.com/documentation/avfoundation/avroutedetector/2915762-routedetectionenabled
        self.playerView.controlsView.routeDetector.routeDetectionEnabled = NO;
    }
}

#pragma mark - BCOVPUIPlayerViewDelegate

- (void)pictureInPictureControllerDidStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController
{
    NSLog(@"pictureInPictureControllerDidStartPictureInPicture");
}

- (void)pictureInPictureControllerDidStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController
{
    NSLog(@"pictureInPictureControllerDidStopPictureInPicture");
}

- (void)pictureInPictureControllerWillStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController
{
    NSLog(@"pictureInPictureControllerWillStartPictureInPicture");
}

- (void)pictureInPictureControllerWillStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController
{
    NSLog(@"pictureInPictureControllerWillStopPictureInPicture");
}

- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController failedToStartPictureInPictureWithError:(NSError *)error
{
    NSLog(@"failedToStartPictureInPictureWithError: %@", error.localizedDescription);
}

@end
