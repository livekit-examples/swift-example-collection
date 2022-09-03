//
//  AppDelegate.m
//  objc-minimal
//
//  Created by Hiroshi Horie on 2022/09/02.
//

#import "AppDelegate.h"
#import "ViewController.h"

@interface AppDelegate () {
}
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {

    NSLog(@"applicationDidFinishLaunching");

    // NSRect frame = NSMakeRect(100, 100, 200, 200);
    NSWindow* window  = [[NSWindow alloc] initWithContentRect:NSZeroRect
                                                    styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskResizable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskClosable)
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO];

    window.contentViewController = [[ViewController alloc] initWithNibName:nil bundle:nil];

    [window setBackgroundColor:[NSColor blueColor]];
    [window makeKeyAndOrderFront:NSApp];

    _window = window;
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}


@end
