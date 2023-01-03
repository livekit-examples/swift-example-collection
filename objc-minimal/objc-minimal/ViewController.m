//
//  ViewController.m
//  objc-minimal
//
//  Created by Hiroshi Horie on 2022/09/02.
//

#import "ViewController.h"

@import LiveKit;

@interface ViewController () <RoomDelegateObjC> {
  Room *_room;
  VideoView *_localVideoView;
  VideoView *_remoteVideoView;
}

@end

@implementation ViewController

- (void)room:(Room *)room
    didUpdateConnectionState:(enum ConnectionState)connectionState
          oldConnectionState:(enum ConnectionState)oldConnectionState {

  NSLog(@"didUpdate connectionState: %ld", (long)connectionState);
}

- (void)room:(Room *)room
         localParticipant:(LocalParticipant *)localParticipant
    didPublishPublication:(LocalTrackPublication *)publication {

  id localTrack = publication.track;
  // filter out audio tracks etc
  if ([localTrack conformsToProtocol:@protocol(VideoTrack)]) {
    _localVideoView.track = localTrack;
  }
}

- (void)room:(Room *)room
                participant:(RemoteParticipant *)participant
    didSubscribePublication:(RemoteTrackPublication *)publication
                      track:(Track *)track {

  id remoteTrack = publication.track;
  // filter out audio tracks etc
  if ([remoteTrack conformsToProtocol:@protocol(VideoTrack)]) {
    _remoteVideoView.track = remoteTrack;
  }
}

- (void)loadView {

  Room *room = [[Room alloc] initWithDelegate:self
                               connectOptions:nil
                                  roomOptions:nil];

  _room = room;

  // Prepare parent View

  NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(100, 100, 300, 300)];
  view.wantsLayer = YES;
  view.layer.backgroundColor = NSColor.redColor.CGColor;

  // Prepare VideoView

  _localVideoView = [[VideoView alloc] initWithFrame:view.frame];
  _localVideoView.debugMode = YES;
  _localVideoView.wantsLayer = YES;
  _localVideoView.layer.backgroundColor = NSColor.greenColor.CGColor;
  [view addSubview:_localVideoView];

  _remoteVideoView = [[VideoView alloc] initWithFrame:view.frame];
  _remoteVideoView.debugMode = YES;
  _remoteVideoView.wantsLayer = YES;
  _remoteVideoView.layer.backgroundColor = NSColor.purpleColor.CGColor;
  [view addSubview:_remoteVideoView];

  self.view = view;
}

- (void)viewDidLoad {
  [super viewDidLoad];

  // Do any additional setup after loading the view.

  NSLog(@"view did load");

  // Connect to Room

  FBLPromise<Room *> *connectPromise =
      [_room connectWithURL:@"wss://_____.livekit.cloud"
                      token:@""
             connectOptions:nil
                roomOptions:nil];

  FBLPromise *promise =
      [connectPromise then:^id _Nullable(Room *_Nullable room) {
        // Successfully connected
        NSLog(@"Connected to region: %@", room.serverRegion);

        // Publish
        [room.localParticipant setCameraEnabled:YES];
        [room.localParticipant setMicrophoneEnabled:YES];

        return nil;
      }];

  [promise catch:^(NSError *_Nonnull error) {
    // Connect error
    NSLog(@"Failed to connect with error: %@", error);
  }];
}

- (void)viewDidLayout {
  [super viewDidLayout];
  CGSize size = self.view.bounds.size;
  // Local view on the left side
  _localVideoView.frame = CGRectMake(0, 0, size.width / 2, size.height);
  // Local view on the right side
  _remoteVideoView.frame = CGRectMake(_localVideoView.frame.size.width, 0,
                                      size.width / 2, size.height);
}

- (void)viewWillDisappear {
  [_room disconnect];
}

- (void)setRepresentedObject:(id)representedObject {
  [super setRepresentedObject:representedObject];

  // Update the view, if already loaded.
}

@end
