//
//  BTLECentralViewController.mm
//  FiftyThreeSdkTestApp
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
#include "Common/Timer.h"

#include "FiftyThreeSdk/FTPenAndTouchManager.h"
#include "FiftyThreeSdk/FTTouchEventLogger.h"
#import <MessageUI/MessageUI.h>

#import <CoreBluetooth/CoreBluetooth.h>

#include <boost/foreach.hpp>
#include <boost/smart_ptr.hpp>
#include <sstream>

using namespace fiftythree::common;
using namespace fiftythree::canvas;
using namespace fiftythree::sdk;
using boost::static_pointer_cast;
using boost::dynamic_pointer_cast;
using boost::shared_ptr;
using boost::make_shared;
using std::stringstream;

NSString * const kUpdateProgressViewMessage = @"%.1f%% Complete\nTime Remaining: %02d:%02d";

class TouchObserver;

@interface BTLECentralViewController () <FTPenManagerDelegate, FTPenDelegate, FTPenManagerDelegatePrivate, UIAlertViewDelegate, MFMailComposeViewControllerDelegate>
{
    FTPenAndTouchManager::Ptr _PenAndTouchManager;
    FTTouchEventLogger::Ptr _EventLogger;
    Touch::cPtr _SelectedTouch;
    BOOL _SelectedTouchHighlighted; // the state the stroke was in before touched
    std::vector<Touch::cPtr> _HighlightedTouches;
    Timer::Ptr _ConnectTimer;
    shared_ptr<TouchObserver> _TouchObserver;
    Touch::cPtr _StrokeTouch;
}

- (void)startTrialSeparation;
- (void)touchTypeChanged:(const Touch::cPtr &)touch;

@property (nonatomic) FTPenManager *penManager;
@property (nonatomic) id currentTest;
@property (nonatomic) UIAlertView *updateProgressView;
@property (nonatomic) UIAlertView *updateStartView;
@property (nonatomic) UIAlertView *clearAlertView;
@property (nonatomic) NSDate *updateStart;
@property (nonatomic) GLCanvasController *canvasController;
@property (nonatomic) BOOL annotationMode;
@property (nonatomic) BOOL pairing;

@property (nonatomic) long tipDownCount;
@property (nonatomic) long tipUpCount;
@property (nonatomic) NSDate *firstTipDate;
@property (nonatomic) NSDate *lastTipDate;
@property (nonatomic) long connectCount;
@property (nonatomic) NSDate *firstConnectDate;
@property (nonatomic) NSDate *lastConnectDate;

@end

class TouchObserver
{
private:
    BTLECentralViewController *_vc;

public:
    TouchObserver(BTLECentralViewController *vc)
    {
        _vc = vc;
    }

    void TouchTypeChanged(const Event<const Touch::cPtr &> & event, const Touch::cPtr & touch)
    {
        [_vc touchTypeChanged:touch];
    }

    void ShouldStartTrialSeparation(const Event<Unit> & event, Unit unit)
    {
        [_vc startTrialSeparation];
    }

    void EngineError(const Event<const std::string &> & event, const std::string & str)
    {
        std::cout << str << std::endl;
    }

};

@implementation BTLECentralViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillEnterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];

    self.view.multipleTouchEnabled = YES;

    _penManager = [[FTPenManager alloc] initWithDelegate:self];
    _penManager.autoConnect = YES;

    _PenAndTouchManager = FTPenAndTouchManager::New();
    _PenAndTouchManager->RegisterForEvents();
    _EventLogger = FTTouchEventLogger::New();
    _PenAndTouchManager->SetLogger(_EventLogger);

    _TouchObserver = make_shared<TouchObserver>(self);
    _PenAndTouchManager->TouchTypeChanged().AddListener(_TouchObserver, &TouchObserver::TouchTypeChanged);
    _PenAndTouchManager->ShouldStartTrialSeparation().AddListener(_TouchObserver, &TouchObserver::ShouldStartTrialSeparation);
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
    self.canvasController.engine->UnexpectedError().AddListener(_TouchObserver, &TouchObserver::EngineError);
    [self.view addSubview:self.canvasController.view];
    [self.view sendSubviewToBack:self.canvasController.view];

    self.canvasController.view.multipleTouchEnabled = YES;
    self.view.multipleTouchEnabled = YES;

    static_pointer_cast<TouchTrackerObjC>(TouchTracker::Instance())->RegisterView(self.view);
    static_pointer_cast<TouchManagerObjC>(TouchManager::Instance())->RegisterView(_canvasController.view);

    [self updateDisplay];
}

- (void)viewDidUnload
{
}

- (void)viewDidDisappear:(BOOL)animated
{
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

- (void)connect
{
    if (self.penManager.pen && !self.penManager.pen)
    {
        _ConnectTimer = Timer::New();
        NSAssert(0, @"Unimplemented");
//        [self.penManager connect];
    }
}

- (void)applicationWillEnterForeground:(NSNotification *)notification
{
    [self connect];
}

- (void)penManagerDidUpdateState:(FTPenManager *)penManager
{
    [self connect];

    [self updateDisplay];
}

- (void)penManager:(FTPenManager *)penManager didPairWithPen:(FTPen *)pen
{
//    NSLog(@"didPairWithPen name=%@", pen.name);

    [self updateDisplay];

    [self.currentTest penManager:penManager didPairWithPen:pen];
}

- (void)penManager:(FTPenManager *)penManager didUnpairFromPen:(FTPen *)pen
{
//    NSLog(@"didUnpairFromPen name=%@", pen.name);

    [self updateDisplay];

    [self.currentTest penManager:penManager didUnpairFromPen:pen];
}

- (void)penManager:(FTPenManager *)penManager didConnectToPen:(FTPen *)pen
{
    // Stats
    self.connectCount++;
    if (!self.firstConnectDate)
    {
        self.firstConnectDate = [NSDate date];
    }
    self.lastConnectDate = [NSDate date];

    _PenAndTouchManager->SetPalmRejectionEnabled(true);

    if (_ConnectTimer)
    {
        NSLog(@"connect took %f seconds", _ConnectTimer->ElapsedTimeSeconds());
        _ConnectTimer.reset();
    }

//    NSLog(@"didConnectToPen name=%@", pen.name);

    pen.delegate = self;

    [self updateDisplay];

    [self.currentTest penManager:penManager didConnectToPen:pen];
}

- (void)penManager:(FTPenManager *)penManager didFailConnectToPen:(FTPen *)pen
{
//    NSLog(@"didFailConnectToPen name=%@", pen.name);

    [self updateDisplay];

    [self.currentTest penManager:penManager didFailConnectToPen:pen];
}

- (void)penManager:(FTPenManager *)penManager didDisconnectFromPen:(FTPen *)pen
{
//    NSLog(@"didDisconnectFromPen name=%@", pen.name);

    _PenAndTouchManager->SetPalmRejectionEnabled(false);

    [self updateDisplay];

    [self.currentTest penManager:penManager didDisconnectFromPen:pen];
}

- (void)pen:(FTPen *)pen isTipPressedDidChange:(BOOL)isTipPressed
{
    // Stats
    self.tipDownCount++;
    if (!self.firstTipDate)
    {
        self.firstTipDate = [NSDate date];
    }
    self.lastTipDate = [NSDate date];

    [self.tip1State setHighlighted:isTipPressed];

    PenEvent::Ptr event = PenEvent::New([NSProcessInfo processInfo].systemUptime,
                                        isTipPressed ? PenEventType::PenDown : PenEventType::PenUp,
                                        PenTip::Tip1);

    _PenAndTouchManager->HandlePenEvent(event);
}

- (void)pen:(FTPen *)pen isEraserPressedDidChange:(BOOL)isEraserPressed
{
    // Stats
    self.tipDownCount++;
    if (!self.firstTipDate)
    {
        self.firstTipDate = [NSDate date];
    }
    self.lastTipDate = [NSDate date];

    [self.tip2State setHighlighted:isEraserPressed];

    PenEvent::Ptr event = PenEvent::New([NSProcessInfo processInfo].systemUptime,
                                        isEraserPressed ? PenEventType::PenDown : PenEventType::PenUp,
                                        PenTip::Tip2);
    _PenAndTouchManager->HandlePenEvent(event);
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
    NSLog(@"PnPID.vendorId = %d", pen.pnpId.vendorId);
    NSLog(@"PnPID.vendorIdSource = %d", pen.pnpId.vendorIdSource);
    NSLog(@"PnPID.productId = %d", pen.pnpId.productId);
    NSLog(@"PnPID.productVersion = %d", pen.pnpId.productVersion);

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

- (void)updateDisplay
{
    if (self.penManager.pen)
    {
        if (self.penManager.pen.isReady)
        {
            [self.pairingStatusLabel setText:[NSString stringWithFormat:@"Connected to %@",
                                              self.penManager.pen.name]];
        }
        else
        {
            [self.pairingStatusLabel setText:[NSString stringWithFormat:@"Connecting to %@",
                                              self.penManager.pen.name]];
        }
    }
//    else if (self.pairing)
//    {
//        [self.pairingStatusLabel setText:@"Pairing"];
//    }
//    else if (self.penManager.pen)
//    {
//        [self.pairingStatusLabel setText:[NSString stringWithFormat:@"Paired with %@",
//                                          self.penManager.pen.name]];
//    }
//    else
//    {
//        [self.pairingStatusLabel setText:@"Unpaired"];
//    }

    if (self.penManager.pen)
    {
        [self.connectButton setTitle:@"Disconnect" forState:UIControlStateNormal];
        self.updateFirmwareButton.hidden = NO;
//        self.trialSeparationButton.hidden = NO;
    }
    else
    {
        [self.connectButton setTitle:@"Connect" forState:UIControlStateNormal];
        self.updateFirmwareButton.hidden = YES;
//        self.trialSeparationButton.hidden = YES;

        self.tip1State.highlighted = NO;
        self.tip2State.highlighted = NO;
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

    if (self.penManager.pen)
    {
        self.testConnectButton.hidden = NO;
        self.connectButton.hidden = NO;
    }
    else
    {
        self.testConnectButton.hidden = YES;
        self.connectButton.hidden = YES;
    }
}

- (IBAction)pairButtonPressed:(id)sender
{
    [self.penManager pairingSpotWasPressed];
    self.pairing = YES;
    [self updateDisplay];
}

- (IBAction)pairButtonReleased:(id)sender
{
    [self.penManager pairingSpotWasReleased];
    self.pairing = NO;
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
    if (!self.penManager.pen)
    {
        [self connect];
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
//    [self.penManager deletePairedPen:self.penManager.pairedPen];

    [self updateDisplay];
}

- (IBAction)updateFirmwareButtonPressed:(id)sender
{
    [self queryFirmwareUpdate:YES];
}

- (IBAction)trialSeparationButtonPressed:(id)sender
{
    [self startTrialSeparation];
}

- (void)showUpdateStartView
{
    self.updateStartView = [[UIAlertView alloc] initWithTitle:@"Firmware Update" message:@"Update available. Update Now?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Ok", nil];
    [self.updateStartView show];
}

- (void)checkForUpdates
{
    NSLog(@"Checking for updates...");

    if ([self.penManager isUpdateAvailableForPen:self.penManager.pen])
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
    if (forced
        || [self.penManager isUpdateAvailableForPen:self.penManager.pen])
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

    [self.penManager updateFirmwareForPen:self.penManager.pen];
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
            _StrokeTouch.reset();

            self.tipDownCount = 0;
            self.tipUpCount = 0;
            self.firstTipDate = nil;
            self.lastTipDate = nil;

            self.connectCount = 0;
            self.firstConnectDate = nil;
            self.lastConnectDate = nil;
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
    Touch::cPtr nearest = static_pointer_cast<FTTouchEventLoggerObjc>(_EventLogger)->NearestStrokeForTouch(touch);

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

- (void)drawStrokeFromTouch:(Touch::cPtr)touch
{
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

    [self drawStrokeFromTouch:touch];
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

- (BOOL)shouldDrawTouch:(const Touch::cPtr &)touch
{
    if (self.penManager.pen)
    {
        TouchType type = _PenAndTouchManager->GetTouchType(touch);

        return type != TouchType::Finger;
    }
    else
    {
        return YES;
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

        for (UITouch *uiTouch in touches)
        {
            Touch::cPtr touch = static_pointer_cast<TouchTrackerObjC>(TouchTracker::Instance())->TouchForUITouch(uiTouch);

            if ([self shouldDrawTouch:touch] && !_StrokeTouch)
            {
                [self.canvasController beginStroke:touch->CurrentSample()];
                _StrokeTouch = touch;
            }
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

        for (UITouch *uiTouch in touches)
        {
            Touch::cPtr touch = static_pointer_cast<TouchTrackerObjC>(TouchTracker::Instance())->TouchForUITouch(uiTouch);
            if (touch == _StrokeTouch)
            {
                [self.canvasController continueStroke:touch->CurrentSample()];
            }
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

        for (UITouch *uiTouch in touches)
        {
            Touch::cPtr touch = static_pointer_cast<TouchTrackerObjC>(TouchTracker::Instance())->TouchForUITouch(uiTouch);
            if (touch == _StrokeTouch)
            {
                [self.canvasController endStroke:touch->CurrentSample()];
                _StrokeTouch.reset();
            }
        }
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (touches.count >= 4)
    {
        [self didDetectMultitaskingGesturesEnabled];
    }

    if (self.annotationMode)
    {
        _SelectedTouch.reset();
        return;
    }

    if ([self shouldProcessTouches:touches])
    {
        static_pointer_cast<TouchManagerObjC>(TouchManager::Instance())->ProcessTouches(touches);

        for (UITouch *uiTouch in touches)
        {
            Touch::cPtr touch = static_pointer_cast<TouchTrackerObjC>(TouchTracker::Instance())->TouchForUITouch(uiTouch);
            if (touch == _StrokeTouch)
            {
                [self.canvasController cancelStroke];
                _StrokeTouch.reset();
            }
        }
    }
}

- (void)startTrialSeparation
{
    [self.penManager startTrialSeparation];
}

- (void)touchTypeChanged:(const Touch::cPtr &)touch
{
    DebugAssert(self.penManager.pen);

    if (_StrokeTouch == touch)
    {
        if (![self shouldDrawTouch:touch])
        {
            _StrokeTouch.reset();

            [self.canvasController cancelStroke];
        }
    }
    else if ([self shouldDrawTouch:touch])
    {
        if (_StrokeTouch)
        {
            [self.canvasController cancelStroke];
        }

        _StrokeTouch = touch;

        [self drawStrokeFromTouch:touch];
    }
}

- (IBAction)infoButtonPressed:(id)sender
{
    NSDateFormatter *format = [[NSDateFormatter alloc] init];
    [format setDateFormat:@"MMM dd, yyyy HH:mm:ss"];

    FTPen* pen = self.penManager.pen;
    NSString *info = [NSString stringWithFormat:@"\
Manufacturer = %@\n \
Model Number = %@\n \
Serial Number = %@\n \
Firmware Revision = %@\n \
Hardware Revision = %@\n \
Software Revision = %@\n \
System ID = %@\n \
Battery Level = %lu\n \
                      \n \
Tip Press Count = %lu\n \
Tip Release Count = %lu\n \
First Tip Date = %@\n \
Last Tip Date = %@\n \
                      \n \
Connect Count = %lu\n \
First Connect Date = %@\n \
Last Connect Date = %@\n \
                      ", pen.manufacturerName, pen.modelNumber, pen.serialNumber, pen.firmwareRevision, pen.hardwareRevision,
                      pen.softwareRevision, pen.systemId, (long)pen.batteryLevel,
                      self.tipDownCount, self.tipUpCount, [format stringFromDate:self.firstTipDate], [format stringFromDate:self.lastTipDate],
                      self.connectCount, [format stringFromDate:self.firstConnectDate], [format stringFromDate:self.lastConnectDate]];

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

    [picker setSubject:@"Pen and Touch Event Data"];

    NSArray *toRecipients = [NSArray arrayWithObjects:@"adam@fiftythree.com",
                             nil];
    [picker setToRecipients:toRecipients];

    NSMutableData* data = static_pointer_cast<FTTouchEventLoggerObjc>(_EventLogger)->GetData();

    BOOST_FOREACH(const Touch::cPtr & touch, _HighlightedTouches)
    {
        stringstream ss;
        ss << "strokestate=" << touch->Id() << ","
            << 1 << std::endl;
        [data appendBytes:ss.str().c_str() length:ss.tellp()];
    }
    [picker addAttachmentData:data mimeType:@"application/prd" fileName:@"strokedata.ptd"]; // todo - add counter to filename?

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
