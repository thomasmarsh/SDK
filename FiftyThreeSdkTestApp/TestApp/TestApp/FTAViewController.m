//
//  FTAViewController.m
//  TestApp
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#import <FiftyThreeSdk/FiftyThreeSdk.h>

#import "FTADrawer.h"
#import "FTASettingsViewController.h"
#import "FTAUtil.h"
#import "FTAViewController.h"

@interface FTAViewController () <FTTouchClassificationsChangedDelegate,
                                 FTPenManagerDelegate,
                                 UIPopoverControllerDelegate> {

    NSDictionary *_strokeColors;
}
@property (nonatomic) UIToolbar *bar;
@property (nonatomic) BOOL isPencilEnabled;

@property (nonatomic) UIPopoverController *popover;
@property (nonatomic) FTASettingsViewController *popoverContents;

@property (nonatomic) FTADrawer *drawer;

@end

@implementation FTAViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    // We use a basic GL view for rendering some ink and showing
    // touch classifications. The GL code is in FTADrawer. The details
    // aren't really relevant to using FiftyThree SDK.

    self.drawer = [[FTADrawer alloc] init];
    self.drawer.scale = self.view.contentScaleFactor;
    GLKView *view = (GLKView *)self.view;
    view.context = self.drawer.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormatNone;
    self.drawer.view = view;

    // We add a number of bar buttons for testing.
    // (1) A button to tear down FTPenManager
    // (2) A button to startup FTPenManager
    // (3) A Button to clear the page of ink.
    // (4) A button to show a popover with Pen status. This uses the FTPenInformation API to
    //     populate a table view. See FTASettingsViewController.
    self.bar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, MAX(self.view.frame.size.width,self.view.frame.size.height), 44)];

    UIBarButtonItem *button1 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop
                                                                             target:self
                                                                             action:@selector(shutdownFTPenManager:)];
    UIBarButtonItem *button2 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay
                                                                             target:self
                                                                             action:@selector(initializeFTPenManager:)];

    UIBarButtonItem *spacer1 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                             target:nil
                                                                             action:nil];

    UIBarButtonItem *button3 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                             target:self
                                                                             action:@selector(clearScene:)];

    UIBarButtonItem *button4 = [[UIBarButtonItem alloc] initWithTitle:@"   Info   "
                                                                style:UIBarButtonItemStylePlain
                                                               target:self
                                                               action:@selector(showInfo:)];

    [self.bar setItems:@[button1, button2, spacer1, button3, button4]];
    self.bar.barStyle = UIBarStyleBlack;
    self.bar.translucent = NO;

    [self.view addSubview:self.bar];
    self.isPencilEnabled = NO;

    // Defaults to 30, we ant to catch any performance problems so we crank it up.
    self.preferredFramesPerSecond = 60;

    _strokeColors =
    @{
      @(FTTouchClassificationUnknownDisconnected) : [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.3],
      @(FTTouchClassificationUnknown) : [UIColor colorWithRed:0.3 green:0.4 blue:0.1 alpha:0.5],
      @(FTTouchClassificationPen) : [UIColor colorWithRed:0.1 green:0.3 blue:0.9 alpha:0.5],
      @(FTTouchClassificationEraser) : [UIColor colorWithRed:0.9 green:0.1 blue:0.0 alpha:0.5],
      @(FTTouchClassificationFinger) : [UIColor colorWithRed:0.0 green:0.9 blue:0.0 alpha:0.5],
      @(FTTouchClassificationPalm) : [UIColor colorWithRed:0.1 green:0.2 blue:0.1 alpha:0.5]
    };

    // Multi touch is required for processing palm and pen touches.
    // See handleTouches below.
    [self.view setMultipleTouchEnabled:YES];
    [self.view setUserInteractionEnabled:YES];
    [self.view setExclusiveTouch:NO];
}

#pragma mark - Bar Button Press handlers.
- (void)showInfo:(id)sender
{
    UIBarButtonItem *barButton = (UIBarButtonItem*)sender;

    self.popover = nil;
    self.popoverContents = nil;

    if (self.isPencilEnabled)
    {
        self.popoverContents = [[FTASettingsViewController alloc] init];
        self.popoverContents.info = [FTPenManager sharedInstance].info;

        self.popover = [[UIPopoverController alloc] initWithContentViewController:self.popoverContents];
        self.popover.delegate = self;
        [self.popover presentPopoverFromBarButtonItem:barButton permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
    }
}

- (void)clearScene:(id)sender
{
    [self.drawer removeAllStrokes];
}

- (void)shutdownFTPenManager:(id)sender
{
    // Make sure you don't retain any instances of FTPenManager
    // as that will be dealloced to free up CoreBluetooth for other
    // stylus SDKs.
    [[FTPenManager sharedInstance] shutdown];
    self.isPencilEnabled = NO;
    if (self.popover)
    {
        [self.popover dismissPopoverAnimated:NO];
        self.popover = nil;
    }
}

- (void)initializeFTPenManager:(id)sender
{
    UIView *connectionView = [[FTPenManager sharedInstance] pairingButtonWithStyle:FTPairingUIStyleDark
                                                        andTintColor:nil
                                                            andFrame:CGRectZero];

    connectionView.frame = CGRectMake(0.0f, 768 - 100, connectionView.frame.size.width, connectionView.frame.size.height);
    [self.view addSubview:connectionView];

    [FTPenManager sharedInstance].classifier.delegate = self;
    [FTPenManager sharedInstance].delegate = self;

    // You would only uncomment this if you want to drive the animations & classification
    // from your displayLink, see also the update method in this view controller.
    //[FTPenManager sharedInstance].automaticUpdatesEnabled = NO;

    self.isPencilEnabled = YES;
}

#pragma mark - FTTouchClassificationDelegate
- (void)classificationsDidChangeForTouches:(NSSet *)touches;
{
    for(FTTouchClassificationInfo *info in touches)
    {
        NSLog(@"Touch %d was %d now %d", info.touchId, info.oldValue, info.newValue);
        [self.drawer setColor:_strokeColors[@(info.newValue)] forStroke:info.touchId];
    }
}

#pragma mark - FTPenManagerDelegate
- (void)penManagerNeedsUpdateDidChange;
{
    NSLog(@"penManagerNeedsUpdateDidChange %@", [[FTPenManager sharedInstance] needsUpdate]? @"YES":@"NO");
}
// Invoked when the connection state is altered.
- (void)penManagerStateDidChange:(FTPenManagerState)state
{
    NSLog(@"connection did change %@", FTPenManagerStateToString(state));
}

// Invoked when any of the BTLE information is read off the pen. See FTPenInformation.
- (void)penInformationDidChange
{
    if (self.popoverContents)
    {
        self.popoverContents.info = [FTPenManager sharedInstance].info;
        [self.popoverContents.tableView reloadData];
    }
}

#pragma mark - Touch Handling

// Since we've turned on multi touch we may get
// more than one touch in Began/Moved/Ended. Most iOS samples show something like
// UITouch * t = [touches anyObject];
// This isn't correct if you can have multiple touches and multipleTouchEnabled set to YES.
- (void)handleTouches:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (_isPencilEnabled)
    {
        for (UITouch* touch in touches)
        {
            NSInteger k = [[FTPenManager sharedInstance].classifier idForTouch:touch];

            CGPoint location = [touch locationInView:self.view];
            if (touch.phase == UITouchPhaseBegan)
            {
                [self.drawer appendCGPoint:location forStroke:k];
            }
            else if(touch.phase == UITouchPhaseMoved)
            {
                [self.drawer appendCGPoint:location forStroke:k];
            }
            else if(touch.phase == UITouchPhaseEnded)
            {
                [self.drawer appendCGPoint:location forStroke:k];
            }
            else if (touch.phase == UITouchPhaseCancelled)
            {
                [self.drawer removeStroke:k];
            }
        }
    }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self handleTouches:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self handleTouches:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self handleTouches:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self handleTouches:touches withEvent:event];
}

#pragma mark - GLKView and GLKViewController delegate methods

- (void)update
{
    // You'd only uncomment this if you've set FTPenManager's automaticUpdatesEnabled to NO.
    //    if (self.isPencilEnabled)
    //    {
    //        [[FTPenManager sharedInstance] update];
    //    }
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    [self.drawer draw];
}

#pragma mark - View Controller boiler plate.

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (void)viewWillLayoutSubviews
{
    self.drawer.scale = self.view.contentScaleFactor;
    self.drawer.size = self.view.bounds.size;
}

#pragma mark - UIPopoverViewControllerDelegate

- (BOOL)popoverControllerShouldDismissPopover:(UIPopoverController *)popoverController
{
    return YES;
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    self.popoverContents = nil;
    self.popover = nil;
}

@end
