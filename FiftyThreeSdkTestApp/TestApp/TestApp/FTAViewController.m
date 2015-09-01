//
//  FTAViewController.m
//  TestApp
//
//  Copyright (c) 2015 FiftyThree, Inc. All rights reserved.
//

#import <FiftyThreeSdk/FiftyThreeSdk.h>

#import "FTADrawer.h"
#import "FTASettingsViewController.h"
#import "FTAUtil.h"
#import "FTAViewController.h"

@interface FTAViewController () <FTTouchClassificationsChangedDelegate,
                                 FTPenManagerDelegate,
                                 UIPopoverControllerDelegate,
                                 FTASettingsViewControllerDelegate> {
    NSDictionary *_strokeColors;
}
@property (nonatomic) UIBarButtonItem *fps;
@property (nonatomic) UIBarButtonItem *infoButton;
@property (nonatomic) UIBarButtonItem *updateFirmwareButton;
@property (nonatomic) BOOL isPencilEnabled;

@property (nonatomic) UIPopoverController *popover;
@property (nonatomic) FTASettingsViewController *popoverContents;

@property (nonatomic) FTADrawer *drawer;

@property (nonatomic) FTPenManager *penManager;

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

    // We add a number of bar buttons for testing
    // (1) A button to tear down FTPenManager
    // (2) A button to startup FTPenManager
    // (3) A Button to clear the page of ink
    // (4) A button to trigger firmware update if needed
    // (5) A button to show a popover with Pen status. This uses the FTPenInformation API to
    //     populate a table view. See FTASettingsViewController.
    UIBarButtonItem *shutdownButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop
                                                                                    target:self
                                                                                    action:@selector(disablePencil:)];
    UIBarButtonItem *startupButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay
                                                                                   target:self
                                                                                   action:@selector(enablePencil:)];

    UIBarButtonItem *spacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                            target:nil
                                                                            action:nil];

    self.fps = [[UIBarButtonItem alloc] initWithTitle:nil
                                                style:UIBarButtonItemStylePlain
                                               target:nil
                                               action:nil];
    
    UIBarButtonItem *clearButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                 target:self
                                                                                 action:@selector(clearScene:)];

    self.infoButton = [[UIBarButtonItem alloc] initWithTitle:@"   Info   "
                                                       style:UIBarButtonItemStylePlain
                                                      target:self
                                                      action:@selector(showInfo:)];

    self.infoButton.enabled = NO;

    self.updateFirmwareButton = [[UIBarButtonItem alloc] initWithTitle:@"FW Update"
                                                                 style:UIBarButtonItemStylePlain
                                                                target:self
                                                                action:@selector(updateFirmware:)];

    self.updateFirmwareButton.enabled = NO;

    [self.bar setItems:@[ shutdownButton, startupButton, spacer, self.fps, clearButton, self.updateFirmwareButton, self.infoButton ]];
    self.bar.barStyle = UIBarStyleBlack;
    self.bar.translucent = NO;

    [self.view addSubview:self.bar];

    _isPencilEnabled = NO;

    // Defaults to 30, we want to catch any performance problems so we crank it up
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

    // Multitouch is required for processing palm and pen touches
    // See handleTouches below
    [self.view setMultipleTouchEnabled:YES];
    [self.view setUserInteractionEnabled:YES];
    [self.view setExclusiveTouch:NO];

    // If for some reason you need to check the SDK version you can do the following.
    // Note that this *doesn't* start up CoreBluetooth.
    FTSDKVersionInfo *versionInfo = [[FTSDKVersionInfo alloc] init];
    NSLog(@"FiftyThree SDK Version:%@", versionInfo.version);
}

#pragma mark - Properties

- (void)setIsPencilEnabled:(BOOL)isPencilEnabled
{
    if (_isPencilEnabled != isPencilEnabled) {
        _isPencilEnabled = isPencilEnabled;
        self.penManager = (isPencilEnabled) ? [FTPenManager sharedInstance] : nil;
    }
}

- (void)setPenManager:(FTPenManager *)penManager
{
    if (_penManager != penManager) {
        if (_penManager) {
            // Make sure you don't retain any instances of FTPenManager.
            // It needs to be dealloced to free up CoreBluetooth for other
            // stylus SDKs.
            [_penManager shutdown];
            _penManager = nil;
            self.isPencilEnabled = NO;
        } else {
            _penManager = penManager;
            
            UIView *connectionView = [_penManager pairingButtonWithStyle:FTPairingUIStyleFlat];
            connectionView.translatesAutoresizingMaskIntoConstraints = NO;
            
            [self.view addSubview:connectionView];
            
            NSDictionary* viewsDictionary = NSDictionaryOfVariableBindings(connectionView);
            
            CGSize minimalSize = {0,0};
            CGSize pairingSpotSize = [connectionView sizeThatFits:minimalSize];
            CGFloat barHeight = self.bar.frame.size.height;
            
            [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:[NSString stringWithFormat:@"V:[connectionView(%d)]-(==%d)-|", (int)round(pairingSpotSize.height), (int)round(barHeight)]
                                                                      options:NSLayoutFormatAlignAllBottom
                                                                      metrics:nil
                                                                        views:viewsDictionary]];
            
            [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:[NSString stringWithFormat:@"H:|-[connectionView(%d)]", (int)round(pairingSpotSize.width)]
                                                                     options:0
                                                                     metrics:nil
                                                                       views:viewsDictionary]];
            
            _penManager.classifier.delegate = self;
            _penManager.delegate = self;
            
            // By default the FiftyThree SDK doesn't check for firmware updates.
            // Turn on this check by setting this property. You'll be notified on
            // penManagerFirmwareUpdateIsAvailableDidChange
            _penManager.shouldCheckForFirmwareUpdates = YES;
            
            self.isPencilEnabled = YES;
        }
    }
}

#pragma mark - Bar Button Press handlers.
- (void)updateFirmware:(id)sender
{
    NSNumber *firmwareUpdateIsAvailable = self.penManager.firmwareUpdateIsAvailable;

    if (firmwareUpdateIsAvailable != nil && [firmwareUpdateIsAvailable boolValue]) {
        BOOL isPaperInstalled = self.penManager.canInvokePaperToUpdatePencilFirmware;
        if (isPaperInstalled) {
            // We invoke Paper via url handlers. You can optionally specify urls so that
            // Paper can return to your app. The application name is shown in a button labelled:
            // Back To {Application Name}
            NSString *applicationName = @"SDK Test App";
            // In the plist we register sdktestapp as an url type. See the app delegate.
            NSURL *successUrl = [NSURL URLWithString:@"sdktestapp://x-callback-url/success"];
            NSURL *cancelUrl = [NSURL URLWithString:@"sdktestapp://x-callback-url/cancel"];
            NSURL *errorUrl = [NSURL URLWithString:@"sdktestapp://x-callback-url/error"];

            BOOL result = [self.penManager invokePaperToUpdatePencilFirmware:applicationName
                                                                     success:successUrl
                                                                       error:errorUrl
                                                                      cancel:cancelUrl];

            if (!result) {
                // If we for some reason couldn't open the url. We might alert to user.
            }
        } else {
            // If Paper isn't installed or is too old to support firmware update we'll direct the user
            // to FiftyThree's support site. This site walks them through installing Paper and doing
            // firmware update.
            NSURL *firmwareUpdateSupportUrl = self.penManager.firmwareUpdateSupportLink;
            BOOL result = [[UIApplication sharedApplication] openURL:firmwareUpdateSupportUrl];
            if (!result) {
                // Very unlikely that opening mobile safari would fail. But you might alert the user here.
            }
        }
    }
}

- (void)backPressed:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)showInfo:(id)sender
{
    UIBarButtonItem *barButton = (UIBarButtonItem *)sender;

    self.popover = nil;
    self.popoverContents = nil;

    if (self.isPencilEnabled) {
        self.popoverContents = [[FTASettingsViewController alloc] initWithStyle:UITableViewStylePlain :self];
        self.popoverContents.info = self.penManager.info;

        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            self.popover = [[UIPopoverController alloc] initWithContentViewController:self.popoverContents];
            self.popover.delegate = self;
            [self.popover presentPopoverFromBarButtonItem:barButton permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
        } else {
            UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:self.popoverContents];

            UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle:@"Back"
                                                                           style:UIBarButtonItemStyleBordered
                                                                          target:nil
                                                                          action:@selector(backPressed:)];

            self.popoverContents.navigationItem.leftBarButtonItem = backButton;
            [self presentViewController:navController animated:YES completion:nil];
        }
    }
}

- (void)clearScene:(id)sender
{
    [self.drawer removeAllStrokes];
    self.paused = NO;
}

- (void)disablePencil:(id)sender
{
    self.isPencilEnabled = NO;
    if (self.popover) {
        [self.popover dismissPopoverAnimated:NO];
        self.popover = nil;
    }
}

- (void)enablePencil:(id)sender
{
    self.isPencilEnabled = YES;
}

#pragma mark - FTASettingsViewControllerDelegate
- (NSInteger)getFramerate
{
    return self.framesPerSecond;
}

- (void)setFramerate:(NSInteger)framesPerSecond
{
    self.preferredFramesPerSecond = framesPerSecond;
}

#pragma mark - FTTouchClassificationDelegate
- (void)classificationsDidChangeForTouches:(NSSet *)touches;
{
    for (FTTouchClassificationInfo *info in touches) {
        [self.drawer setColor:_strokeColors[@(info.newValue)] forStroke:info.touchId];
    }
    self.paused = NO;
}

#pragma mark - FTPenManagerDelegate
// Invoked when the connection state is altered.
- (void)penManagerStateDidChange:(FTPenManagerState)state
{
    if (FTPenManagerStateIsConnected(state)) {
        self.infoButton.enabled = YES;
        NSNumber *firmwareUpdateIsAvailable = self.penManager.firmwareUpdateIsAvailable;
        self.updateFirmwareButton.enabled = (firmwareUpdateIsAvailable != nil && [firmwareUpdateIsAvailable boolValue]);
    } else {
        self.updateFirmwareButton.enabled = NO;
        self.infoButton.enabled = NO;
    }
}

// Invoked when any of the BTLE information is read off the pen. See FTPenInformation.
- (void)penInformationDidChange
{
    if (self.popoverContents) {
        self.popoverContents.info = self.penManager.info;
        [self.popoverContents.tableView reloadData];
    }
}

// This is optional.
- (void)penManagerFirmwareUpdateIsAvailableDidChange
{
    NSNumber *firmwareUpdateIsAvailable = self.penManager.firmwareUpdateIsAvailable;

    if (firmwareUpdateIsAvailable != nil && [firmwareUpdateIsAvailable boolValue]) {
        // Note, we always enable the button but if Paper isn't installed that button
        // will open the support site.
        self.updateFirmwareButton.enabled = YES;
    } else {
        self.updateFirmwareButton.enabled = NO;
    }
}

// This also is optional.
- (void)penManagerNeedsUpdate
{
    self.paused = NO;
}

#pragma mark - Touch Handling

// Since we've turned on multi touch we may get
// more than one touch in Began/Moved/Ended. Most iOS samples show something like
// UITouch * t = [touches anyObject];
// This isn't correct if you can have multiple touches and multipleTouchEnabled set to YES.
- (void)handleTouches:(NSSet *)touches withEvent:(UIEvent *)event
{

    if (self.isPencilEnabled) {
        BOOL didChange = NO;
        FTPenManager *penManager = self.penManager;
        for (UITouch *touch in touches) {
            NSInteger k = [penManager.classifier idForTouch:touch];

            CGPoint location = [touch locationInView:self.view];

            // We also surface unfiltered radius. This is very quantized.
            // NSNumber *radius = [penManager normalizedRadiusForTouch:touch];
            NSNumber *smoothedRadius = [penManager smoothedRadiusForTouch:touch];

            CGFloat r = 4;
            if (smoothedRadius) {
                r = [smoothedRadius floatValue];
                r = MAX(r, 1.0f);
                r = MIN(r, 85.0f);
            }

            if (touch.phase == UITouchPhaseBegan) {
                [self.drawer appendCGPoint:location andRadius:r forStroke:k];
                didChange = YES;
            } else if (touch.phase == UITouchPhaseMoved) {
                [self.drawer appendCGPoint:location andRadius:r forStroke:k];
                didChange = YES;
            } else if (touch.phase == UITouchPhaseEnded) {
                [self.drawer appendCGPoint:location andRadius:r forStroke:k];
                didChange = YES;
            } else if (touch.phase == UITouchPhaseCancelled) {
                [self.drawer removeStroke:k];
                didChange = YES;
            }
            if (didChange) {
                self.paused = NO;
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
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    self.paused = YES;
    if (self.isPencilEnabled && !self.penManager.automaticUpdatesEnabled) {
        [self.penManager update];
    }
    [self.drawer draw];
    self.fps.title = [NSString stringWithFormat:@"%ld@%ld", self.framesDisplayed, self.framesPerSecond];
    
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
    BOOL changed = NO;
    if (self.drawer.scale != self.view.contentScaleFactor) {
        self.drawer.scale = self.view.contentScaleFactor;
        changed = YES;
    }
    if (self.drawer.size.width != self.view.bounds.size.width ||
        self.drawer.size.height != self.view.bounds.size.height)
    {
        self.drawer.size = self.view.bounds.size;
        changed = YES;
    }
    if (changed) {
        self.paused = NO;
    }
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
