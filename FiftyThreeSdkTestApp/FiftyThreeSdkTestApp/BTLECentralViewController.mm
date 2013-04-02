//
//  BTLECentralViewController.m
//  charcoal-prototype
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "BTLECentralViewController.h"
#import "FiftyThreeSdk/FTPenManager.h"
#import "FiftyThreeSdk/FTPenManager+Private.h"
#import "FTConnectLatencyTester.h"
#include "Canvas/GLCanvasController.h"
#include "Common/InputSample.h"
#include "Common/TouchManager.h"

#include "FiftyThreeSdk/FTPenAndTouchLogger.h"

using namespace fiftythree::common;
using namespace fiftythree::canvas;
using namespace fiftythree::sdk;
using boost::static_pointer_cast;
using boost::dynamic_pointer_cast;

NSString * const kUpdateAlertViewMessage = @"%.1f%% Complete\nTime Remaining: %02d:%02d";

@interface BTLECentralViewController () <FTPenManagerDelegate, FTPenDelegate, FTPenManagerDelegatePrivate, UIAlertViewDelegate>
{
    FTPenAndTouchLogger::Ptr _TouchLogger;
}

@property (nonatomic) FTPenManager *penManager;
@property (nonatomic) id currentTest;
@property (nonatomic) UIAlertView *updateAlertView;
@property (nonatomic) NSDate *updateStart;
@property (nonatomic) GLCanvasController *canvasController;

@end

@implementation BTLECentralViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _TouchLogger = FTPenAndTouchLogger::New();
    _TouchLogger->StartLogging();
}

- (void)viewWillAppear:(BOOL)animated
{
    CGRect frame = self.view.bounds;
    frame.size.height -= 44; // 44 = height of bottom toolbar
    
    self.canvasController = [[GLCanvasController alloc] initWithFrame:frame
                                                             andScale:[UIScreen mainScreen].scale];
    [self.canvasController setBrush:@"FountainPen"];
    self.canvasController.view.hidden = NO;
    self.canvasController.paused = NO;    
    [self.view addSubview:self.canvasController.view];
    [self.view sendSubviewToBack:self.canvasController.view];
    
    _penManager = [[FTPenManager alloc] initWithDelegate:self];
    while (!_penManager.isReady) {}

    [_penManager registerView:self.view];
        
    static_pointer_cast<TouchManagerObjC>(TouchManager::Instance())->RegisterView(_canvasController.view);
    
    [self updateDisplay];
}

- (void)viewDidUnload
{
}

- (void)viewDidDisappear:(BOOL)animated
{
    _TouchLogger->StopLogging();

    [_penManager deregisterView:self.view];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    if (interfaceOrientation == UIInterfaceOrientationLandscapeLeft ||
        interfaceOrientation == UIInterfaceOrientationLandscapeRight) {
        return YES;
    }
    return NO;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)penManager:(FTPenManager *)penManager didPairWithPen:(FTPen *)pen
{
    NSLog(@"didPairWithPen name=%@", pen.name);

    [self updateDisplay];

    [self.currentTest penManager:penManager didPairWithPen:pen];
}

- (void)penManager:(FTPenManager *)penManager didConnectToPen:(FTPen *)pen
{
    NSLog(@"didConnectToPen name=%@", pen.name);

    pen.delegate = self;

    [self updateDisplay];

    [self.currentTest penManager:penManager didConnectToPen:pen];
}

- (void)penManager:(FTPenManager *)penManager didFailConnectToPen:(FTPen *)pen
{
    NSLog(@"didFailConnectToPen name=%@", pen.name);

    [self updateDisplay];

    [self.currentTest penManager:penManager didFailConnectToPen:pen];
}

- (void)penManager:(FTPenManager *)penManager didDisconnectFromPen:(FTPen *)pen
{
    NSLog(@"didDisconnectFromPen name=%@", pen.name);

    [self updateDisplay];

    [self.currentTest penManager:penManager didDisconnectFromPen:pen];
}

- (void)pen:(FTPen *)pen didPressTip:(FTPenTip)tip
{
    if (tip == FTPenTip1) {
//        NSLog(@"Tip1 pressed");
        [self.tip1State setHighlighted:YES];
    } else if (tip == FTPenTip2) {
//        NSLog(@"Tip2 pressed");
        [self.tip2State setHighlighted:YES];
    } else {
        NSLog(@"Unsupported tip pressed");
    }
}

- (void)displayPenInfo:(FTPen *)pen
{
    NSLog(@"manufacturer = %@", pen.manufacturerName);
    NSLog(@"model number = %@", pen.modelNumber);
    NSLog(@"serial number = %@", pen.serialNumber);
    NSLog(@"firmware revision = %@", pen.firmwareRevision);
    NSLog(@"hardware revision = %@", pen.hardwareRevision);
    NSLog(@"software revision = %@", pen.softwareRevision);
    NSLog(@"system id = %@", pen.systemId);
    NSLog(@"pnp id = %@", pen.pnpId);
    NSLog(@"certification data = %@", pen.certificationData);
    
    [self updateDisplay];
}

- (void)penManager:(FTPenManager *)penManager didUpdateDeviceInfo:(FTPen *)pen
{
    [self displayPenInfo:pen];
}

- (void)penManager:(FTPenManager *)penManager didUpdateDeviceBatteryLevel:(FTPen *)pen;
{
    NSLog(@"battery level = %d", pen.batteryLevel);
}

- (void)penManager:(FTPenManager *)manager didFinishUpdate:(NSError *)error
{
    NSLog(@"didFinishUpdate");
    
    [self.updateAlertView dismissWithClickedButtonIndex:0 animated:NO];
    self.updateAlertView = nil;
}

- (void)penManager:(FTPenManager *)manager didUpdatePercentComplete:(float)percent
{
    NSLog(@"didUpdatePercentComplete %f", percent);
    
    NSTimeInterval elapsed = -[self.updateStart timeIntervalSinceNow];
    float totalTime = elapsed / (percent / 100.0);
    float remainingTime = totalTime - (totalTime * percent / 100.0);
    int minutes = (int)remainingTime / 60;
    int seconds = (int)remainingTime % 60;

    self.updateAlertView.message = [NSString stringWithFormat:kUpdateAlertViewMessage, percent, minutes, seconds];
    [self.updateAlertView show];
}

- (void)pen:(FTPen *)pen didReleaseTip:(FTPenTip)tip
{
    if (tip == FTPenTip1) {
//        NSLog(@"Tip1 released");
        [self.tip1State setHighlighted:NO];
    } else if (tip == FTPenTip2) {
//        NSLog(@"Tip2 released");
        [self.tip2State setHighlighted:NO];
    } else {
        NSLog(@"Unsupported tip released");
    }
}

- (void)updateDisplay
{
    if (self.penManager.connectedPen)
    {
        [self.pairingStatusLabel setText:[NSString stringWithFormat:@"Connected to %@", self.penManager.pairedPen.name]];
    }
    else if (self.penManager.pairedPen)
    {
        [self.pairingStatusLabel setText:[NSString stringWithFormat:@"Paired with %@", self.penManager.pairedPen.name]];
    }
    else
    {
        [self.pairingStatusLabel setText:@"Unpaired"];
    }
    
    if (self.penManager.connectedPen)
    {
        [self.connectButton setTitle:@"Disconnect" forState:UIControlStateNormal];
    }
    else
    {
        [self.connectButton setTitle:@"Connect" forState:UIControlStateNormal];
    }

    if (self.penManager.pairedPen)
    {
        [self.testConnectButton setHidden:NO];
        [self.connectButton setHidden:NO];
        [self.updateFirmwareButton setHidden:NO];
    }
    else
    {
        [self.testConnectButton setHidden:YES];
        [self.connectButton setHidden:YES];
        [self.updateFirmwareButton setHidden:YES];
    }
}

- (IBAction)pairButtonPressed:(id)sender
{
    [self.penManager startPairing];
    [self updateDisplay];
}

- (IBAction)pairButtonReleased:(id)sender
{
    [self.penManager stopPairing];
    [self updateDisplay];
}

- (IBAction)pairButtonTouchDown:(id)sender
{
    return [self pairButtonPressed:sender];
}

- (IBAction)pairButtonTouchUpInside:(id)sender
{
    return [self pairButtonReleased:sender];
}

- (IBAction)pairButtonTouchUpOutside:(id)sender
{
    return [self pairButtonReleased:sender];
}

- (IBAction)testConnectButtonPressed:(id)sender
{
    self.currentTest = [[FTConnectLatencyTester alloc] initWithPenManager:self.penManager];
    [self.currentTest startTest:^(NSError* error) {
        self.currentTest = nil;
    }];
}

- (IBAction)connectButtonPressed:(id)sender
{
    if (!self.penManager.connectedPen)
    {
        [self.penManager connect];
    }
    else
    {
        [self.penManager disconnect];
    }
}

- (IBAction)disconnectButtonPressed:(id)sender
{
    [self.penManager disconnect];
}

- (IBAction)unpairButtonPressed:(id)sender
{
    [self.penManager deletePairedPen:self.penManager.pairedPen];

    [self updateDisplay];
}

- (IBAction)updateFirmwareButtonPressed:(id)sender
{
    self.updateStart = [NSDate date];
    
    self.updateAlertView = [[UIAlertView alloc] initWithTitle:@"Firmware Update" message:[NSString stringWithFormat:kUpdateAlertViewMessage, 0., 0, 0] delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:nil, nil];
    [self.updateAlertView show];
    
    [self.penManager updateFirmwareForPen:self.penManager.connectedPen];
}

- (void)didDetectMultitaskingGesturesEnabled
{
    UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"Warning" message:@"Multitasking Gestures detected. For the best experience, turn them Off in the Settings app under General" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
    [alertView show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    [self.penManager disconnect];
}



- (BOOL) shouldProcessTouches: (NSSet *)touches
{
    BOOL contained = NO;
    for (UITouch *t in touches)
    {
        CGPoint p = [t locationInView:self.view];
        if (CGRectContainsPoint(_canvasController.view.frame,  p))
        {
            contained = YES;
        }
    }
    return contained;
}

#pragma mark - UIKIt Touches
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if ([self shouldProcessTouches:touches])
    {
        static_pointer_cast<TouchManagerObjC>(TouchManager::Instance())->ProcessTouches(touches);
        
        DebugAssert(touches.count == 1);
        UITouch *touch = [touches anyObject];
        [self.canvasController beginStroke:InputSampleFromCGPoint([touch locationInView:self.view],
                                                                  touch.timestamp)];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    if ([self shouldProcessTouches:touches])
    {
        static_pointer_cast<TouchManagerObjC>(TouchManager::Instance())->ProcessTouches(touches);
        
        DebugAssert([touches count] == 1);
        UITouch *touch = [touches anyObject];
        [self.canvasController continueStroke:InputSampleFromCGPoint([touch locationInView:self.view],
                                                                     touch.timestamp)];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if ([self shouldProcessTouches:touches])
    {
        static_pointer_cast<TouchManagerObjC>(TouchManager::Instance())->ProcessTouches(touches);
        
        DebugAssert([touches count] == 1);
        UITouch *touch = [touches anyObject];
        [self.canvasController endStroke:InputSampleFromCGPoint([touch locationInView:self.view],
                                                                touch.timestamp)];
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    if ([self shouldProcessTouches:touches])
    {
        static_pointer_cast<TouchManagerObjC>(TouchManager::Instance())->ProcessTouches(touches);
        
        DebugAssert([touches count] == 1);
        [self.canvasController cancelStroke];
    }
}

- (IBAction)infoButtonPressed:(id)sender
{
    FTPen* pen = self.penManager.connectedPen;
    NSString *info = [NSString stringWithFormat:@"\
Manufacturer = %@\n \
Model Number = %@\n \
Serial Number = %@\n \
Firmware Revision = %@\n \
Hardware Revision = %@\n \
Software Revision = %@\n \
System ID = %@\n \
PnP ID = %@\n \
Certification Data = %@", pen.manufacturerName, pen.modelNumber, pen.serialNumber, pen.firmwareRevision, pen.hardwareRevision,
                      pen.softwareRevision, pen.systemId, pen.pnpId, pen.certificationData];
    
    UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"Device Information" message:info delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
    [alertView show];
}
@end
