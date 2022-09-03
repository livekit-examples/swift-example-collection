//
//  ViewController.m
//  objc-minimal
//
//  Created by Hiroshi Horie on 2022/09/02.
//

#import "ViewController.h"

@import LiveKit;

@interface ViewController () <TrackDelegate> {
    Room *_room;
    VideoView *_videoView;
    LocalVideoTrack *_localVideoTrack;
}

@end


@implementation ViewController

- (void)loadView {

    Room *room = [[Room alloc] init];
    // ...
    _room = room;

    id options = [[CameraCaptureOptions alloc] init];
    _localVideoTrack = [LocalVideoTrack createCameraTrackWithName:@"camera"
                                                          options:options];
    
//    ConnectOptions *options = [[ConnectOptions alloc] initWithAutoSubscribe:false
//                                 rtcConfiguration:nil
//                                  publishOnlyMode:nil
//                                  protocolVersion:ProtocolVersionV2];

    NSView* view = [[NSView alloc] initWithFrame: NSMakeRect(100, 100, 300, 300)];
    view.wantsLayer = YES;
    view.layer.backgroundColor = NSColor.redColor.CGColor;

    _videoView = [[VideoView alloc] initWithFrame:view.frame];
    _videoView.wantsLayer = YES;
    _videoView.layer.backgroundColor = NSColor.greenColor.CGColor;
    [view addSubview:_videoView];
    
    _videoView.mirrorMode = MirrorModeAuto;
    _videoView.hidden = false;

    self.view = view;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.

    NSLog(@"view did load");

    FBLPromise<Room *> *obj = [_room connectWithUrl:@"ws://localhost"
                                              token:@""
                                     connectOptions:nil
                                        roomOptions:nil];

    FBLPromise *promise = [obj then:^id _Nullable(Room * _Nullable value) {
        NSLog(@"connected to region: %@", value.serverRegion);
        return nil;
    }];

    [promise catch:^(NSError * _Nonnull error) {
        NSLog(@"Failed to connect with error: %@", error);
    }];

    _videoView.track = _localVideoTrack;
    [_localVideoTrack start];
}

- (void)viewDidLayout {
    [super viewDidLayout];
    _videoView.frame = self.view.bounds;
}

- (void)viewWillDisappear {
    [_localVideoTrack stop];
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}


@end
