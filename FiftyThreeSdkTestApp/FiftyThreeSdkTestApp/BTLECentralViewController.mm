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
#include "Common/TouchTracker.h"

#include "FiftyThreeSdk/FTPenAndTouchManager.h"
#include "FiftyThreeSdk/FTTouchEventLogger.h"
#import <MessageUI/MessageUI.h>

#include <boost/foreach.hpp>
#include <sstream>

using namespace fiftythree::common;
using namespace fiftythree::canvas;
using namespace fiftythree::sdk;
using boost::static_pointer_cast;
using boost::dynamic_pointer_cast;
using std::stringstream;

NSString * const kUpdateProgressViewMessage = @"%.1f%% Complete\nTime Remaining: %02d:%02d";

@interface BTLECentralViewController () <FTPenManagerDelegate, FTPenDelegate, FTPenManagerDelegatePrivate, UIAlertViewDelegate, MFMailComposeViewControllerDelegate>
{
    FTPenAndTouchManager::Ptr _PenAndTouchManager;
    FTTouchEventLogger::Ptr _EventLogger;
    Touch::cPtr _SelectedTouch;
    BOOL _SelectedTouchHighlighted; // the state the stroke was in before touched
    std::vector<Touch::cPtr> _HighlightedTouches;
}

@property (nonatomic) FTPenManager *penManager;
@property (nonatomic) id currentTest;
@property (nonatomic) UIAlertView *updateProgressView;
@property (nonatomic) UIAlertView *updateStartView;
@property (nonatomic) UIAlertView *clearAlertView;
@property (nonatomic) NSDate *updateStart;
@property (nonatomic) GLCanvasController *canvasController;
@property (nonatomic) UITouch *strokeTouch;
@property (nonatomic) BOOL annotationMode;

@end

@implementation BTLECentralViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.multipleTouchEnabled = YES;
}

- (void)viewWillAppear:(BOOL)animated
{
    CGRect frame = self.view.bounds;
    frame.size.height -= 44; // 44 = height of bottom toolbar
    
    self.canvasController = [[GLCanvasController alloc] initWithFrame:frame
                                                             andScale:[UIScreen mainScreen].scale];
    [self.canvasController setBrush:@"Rollerball"];
    self.canvasController.view.hidden = NO;
    self.canvasController.paused = NO;    
    [self.view addSubview:self.canvasController.view];
    [self.view sendSubviewToBack:self.canvasController.view];

    self.canvasController.view.multipleTouchEnabled = YES;
    self.view.multipleTouchEnabled = YES;
    
    _penManager = [[FTPenManager alloc] initWithDelegate:self];
    
    static_pointer_cast<TouchTrackerObjC>(TouchTracker::Instance())->RegisterView(self.view);
    static_pointer_cast<TouchManagerObjC>(TouchManager::Instance())->RegisterView(_canvasController.view);
     
    _PenAndTouchManager = FTPenAndTouchManager::New();
    _PenAndTouchManager->RegisterForEvents();
    _EventLogger = FTTouchEventLogger::New();
    _PenAndTouchManager->SetLogger(_EventLogger);

    [self updateDisplay];
}

- (void)viewDidUnload
{
}

- (void)viewDidDisappear:(BOOL)animated
{
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

- (void)penManagerDidUpdateState:(FTPenManager *)penManager
{
    [self updateDisplay];
    
    [_penManager registerView:self.view];
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
        
    [self checkForUpdates];
}

- (void)penManager:(FTPenManager *)penManager didUpdateDeviceBatteryLevel:(FTPen *)pen;
{
    NSLog(@"battery level = %d", pen.batteryLevel);
}

- (void)penManager:(FTPenManager *)manager didFinishUpdate:(NSError *)error
{
    NSLog(@"didFinishUpdate");
    
    [self.updateProgressView dismissWithClickedButtonIndex:0 animated:NO];
    self.updateProgressView = nil;
}

- (void)penManager:(FTPenManager *)manager didUpdatePercentComplete:(float)percent
{
    NSLog(@"didUpdatePercentComplete %f", percent);
    
    NSTimeInterval elapsed = -[self.updateStart timeIntervalSinceNow];
    float totalTime = elapsed / (percent / 100.0);
    float remainingTime = totalTime - (totalTime * percent / 100.0);
    int minutes = (int)remainingTime / 60;
    int seconds = (int)remainingTime % 60;

    self.updateProgressView.message = [NSString stringWithFormat:kUpdateProgressViewMessage, percent, minutes, seconds];
    [self.updateProgressView show];
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
        [self.updateFirmwareButton setHidden:NO];
    }
    else
    {
        [self.connectButton setTitle:@"Connect" forState:UIControlStateNormal];
        [self.updateFirmwareButton setHidden:YES];
    }
    
    if (self.annotationMode)
    {
        [self.annotateButton setTitle:@"Draw" forState:UIControlStateNormal];
        self.navigationItem.title = @"Annotate";
    }
    else
    {
        [self.annotateButton setTitle:@"Annotate" forState:UIControlStateNormal];
        self.navigationItem.title = @"Draw";
        
        [self setInkColorBlack];
    }

    if (self.penManager.pairedPen)
    {
        [self.testConnectButton setHidden:NO];
        [self.connectButton setHidden:NO];
    }
    else
    {
        [self.testConnectButton setHidden:YES];
        [self.connectButton setHidden:YES];
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
    [self queryFirmwareUpdate:YES];
}

- (void)showUpdateStartView
{
    self.updateStartView = [[UIAlertView alloc] initWithTitle:@"Firmware Update" message:@"Update available. Update Now?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Ok", nil];
    [self.updateStartView show];
}

- (void)checkForUpdates
{
    NSLog(@"Checking for updates...");
    
    if ([self.penManager isUpdateAvailableForPen:self.penManager.connectedPen])
    {
        NSLog(@"Update available");
        
        [self showUpdateStartView];
    }
    else
    {
        NSLog(@"None available");
    }
}

- (void)queryFirmwareUpdate:(BOOL)forced
{
    if (forced || [self.penManager isUpdateAvailableForPen:self.penManager.connectedPen])
     {
         [self showUpdateStartView];
     }
     else
     {
         self.updateStartView = [[UIAlertView alloc] initWithTitle:@"Firmware Update" message:@"No update available" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
         [self.updateStartView show];
     }
}

- (void)updateFirmware
{
    self.updateStart = [NSDate date];
    
    self.updateProgressView = [[UIAlertView alloc] initWithTitle:@"Firmware Update" message:[NSString stringWithFormat:kUpdateProgressViewMessage, 0., 0, 0] delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:nil, nil];
    [self.updateProgressView show];
    
    [self.penManager updateFirmwareForPen:self.penManager.connectedPen];
}

- (void)didDetectMultitaskingGesturesEnabled
{
    UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"Warning" message:@"Multitasking Gestures detected. For the best experience, turn them Off in the Settings app under General" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
    [alertView show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView == self.updateProgressView)
    {
        [self.penManager disconnect];
        self.updateProgressView = nil;
    }
    else if (alertView == self.updateStartView)
    {
        if (buttonIndex == 1)
        {
            [self updateFirmware];
        }
        self.updateStartView = nil;
    }
    else if (alertView == self.clearAlertView)
    {
        if (buttonIndex == 1)
        {
            _PenAndTouchManager->Clear();
            _HighlightedTouches.clear();
            [self.canvasController clearCanvas];
            self.clearAlertView = nil;
        }
    }
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

- (Touch::cPtr)findStroke:(UITouch *)uiTouch
{
    Touch::cPtr touch = static_pointer_cast<TouchTrackerObjC>(TouchTracker::Instance())->TouchForUITouch(uiTouch);
    Touch::cPtr nearest = _PenAndTouchManager->NearestStrokeForTouch(touch);
    
    return nearest;
}

- (void)setInkColorRed
{
    [self.canvasController setColorwithRed:1.0 Green:0.0 Blue:0.0 Alpha:1.0];
}

- (void)setInkColorBlack
{
    [self.canvasController setColorwithRed:0.0 Green:0.0 Blue:0.0 Alpha:1.0];
}

- (void)drawStrokeFromTouch:(Touch::cPtr)touch withHighlight:(BOOL)highlight
{
    if (highlight)
    {
        [self setInkColorRed];
    }
    else
    {
        [self setInkColorBlack];
    }
    
    BOOST_FOREACH(const InputSample & sample, *touch->History())
    {
        if (sample == touch->History()->front())
        {
            [self.canvasController beginStroke:sample];
        }
        else if (sample == touch->History()->back())
        {
            [self.canvasController endStroke:sample];
        }
        else
        {
            [self.canvasController continueStroke:sample];
        }
    }
}

- (void)drawStroke:(UITouch *)uiTouch
{
    Touch::cPtr touch = [self findStroke:uiTouch];
    if (touch == _SelectedTouch) return;
    
    if (_SelectedTouch)
    {
        // Set the selected touch back to its original state
        [self drawStrokeFromTouch:_SelectedTouch withHighlight:_SelectedTouchHighlighted];
    }
    
    _SelectedTouch = touch;
    
    if (touch)
    {        
        BOOL highlighted = std::find(_HighlightedTouches.begin(), _HighlightedTouches.end(), touch) != _HighlightedTouches.end();
        _SelectedTouchHighlighted = highlighted;
        
        [self drawStrokeFromTouch:touch withHighlight:!highlighted]; // invert highlight
    }
}

#pragma mark - UIKIt Touches
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (self.annotationMode)
    {
        [self drawStroke:[touches anyObject]];
        return;
    }
    
    if ([self shouldProcessTouches:touches])
    {
        static_pointer_cast<TouchManagerObjC>(TouchManager::Instance())->ProcessTouches(touches);
        
        if (!self.strokeTouch)
        {
            self.strokeTouch = [touches anyObject];
            UITouch *touch = self.strokeTouch;
            [self.canvasController beginStroke:InputSampleFromCGPoint([touch locationInView:touch.window],
                                                                      [touch locationInView:self.view],
                                                                      touch.timestamp)];
        }
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (self.annotationMode)
    {
        [self drawStroke:[touches anyObject]];
        return;
    }
    
    if ([self shouldProcessTouches:touches])
    {
        static_pointer_cast<TouchManagerObjC>(TouchManager::Instance())->ProcessTouches(touches);
        
        if ([touches containsObject:self.strokeTouch])
        {
            UITouch *touch = self.strokeTouch;
            [self.canvasController continueStroke:InputSampleFromCGPoint([touch locationInView:touch.window],
                                                                         [touch locationInView:self.view],
                                                                         touch.timestamp)];
        }
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (self.annotationMode)
    {
        [self drawStroke:[touches anyObject]];
        if (_SelectedTouch)
        {
            if (!_SelectedTouchHighlighted)
            {
                _HighlightedTouches.push_back(_SelectedTouch);
            }
            else
            {
                _HighlightedTouches.erase(std::remove(_HighlightedTouches.begin(), _HighlightedTouches.end(), _SelectedTouch), _HighlightedTouches.end());
            }
        }
        _SelectedTouch.reset();
        return;
    }
    
    if ([self shouldProcessTouches:touches])
    {
        static_pointer_cast<TouchManagerObjC>(TouchManager::Instance())->ProcessTouches(touches);
        
        if ([touches containsObject:self.strokeTouch])
        {
            UITouch *touch = self.strokeTouch;
            [self.canvasController endStroke:InputSampleFromCGPoint([touch locationInView:touch.window],
                                                                    [touch locationInView:self.view],
                                                                    touch.timestamp)];
            self.strokeTouch = nil;
        }
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (self.annotationMode)
    {
        _SelectedTouch.reset();
        return;
    }
    
    if ([self shouldProcessTouches:touches])
    {
        static_pointer_cast<TouchManagerObjC>(TouchManager::Instance())->ProcessTouches(touches);
        
        if ([touches containsObject:self.strokeTouch])
        {
            [self.canvasController cancelStroke];
            self.strokeTouch = nil;
        }
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

- (IBAction)clearButtonPressed:(id)sender
{
    self.clearAlertView = [[UIAlertView alloc] initWithTitle:@"Clear Canvas?" message:@"Are you sure you want to clear the canvas?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Ok", nil];
    [self.clearAlertView show];
}

- (IBAction)annotateButtonPressed:(id)sender
{
    self.annotationMode = !self.annotationMode;
    
    [self updateDisplay];
}

-(void)displayComposerSheet
{
    MFMailComposeViewController *picker = [[MFMailComposeViewController alloc] init];
    picker.mailComposeDelegate = self;
    
    [picker setSubject:@"Palm Rejection Data"];

    NSArray *toRecipients = [NSArray arrayWithObjects:@"adam@fiftythree.com",
                             nil];
    [picker setToRecipients:toRecipients];
    
    NSMutableData* data = static_pointer_cast<FTTouchEventLoggerObjc>(_EventLogger)->GetData();
    data = [NSMutableData dataWithData:data]; // copy so we can edit

    BOOST_FOREACH(const Touch::cPtr & touch, _HighlightedTouches)
    {
        stringstream ss;
        ss << "strokestate=" << touch->Id() << ","
            << 1 << std::endl;
        [data appendBytes:ss.str().c_str() length:ss.tellp()];
    }
    [picker addAttachmentData:data mimeType:@"application/prd" fileName:@"strokedata.prd"]; // todo - add counter to filename?
    
    [self presentViewController:picker animated:YES completion:nil];
}

// The mail compose view controller delegate method
- (void)mailComposeController:(MFMailComposeViewController *)controller
          didFinishWithResult:(MFMailComposeResult)result
                        error:(NSError *)error
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)shareButtonPressed:(id)sender
{
    if (![MFMailComposeViewController canSendMail])
    {
        UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"Share" message:@"Email must be configured to share" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
        [alertView show];
    }
    else
    {
        [self displayComposerSheet];
    }
}
@end
