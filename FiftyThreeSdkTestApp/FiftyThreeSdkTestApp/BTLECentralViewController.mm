//
//  BTLECentralViewController.mm
//  FiftyThreeSdkTestApp
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#include <boost/foreach.hpp>
#include <sstream>

#include "Canvas/GLCanvasController.h"
#include "Common/Memory.h"
#include "Common/Timer.h"
#include "Common/Touch/InputSample.h"
#include "Common/Touch/TouchManager.h"
#include "Common/Touch/TouchTracker.h"
#include "FiftyThreeSdk/FTPenAndTouchManager.h"
#include "FiftyThreeSdk/FTTouchEventLogger.h"

#import <CoreBluetooth/CoreBluetooth.h>
#import <MessageUI/MessageUI.h>

#import "BTLECentralViewController.h"
#import "FiftyThreeSdk/FTFirmwareManager.h"
#import "FiftyThreeSdk/FTFirmwareUpdateProgressView.h"
#import "FiftyThreeSdk/FTPen+Private.h"
#import "FiftyThreeSdk/FTPenManager+Private.h"
#import "FiftyThreeSdk/FTPenManager.h"
#import "FTConnectLatencyTester.h"

using namespace fiftythree::common;
using namespace fiftythree::canvas;
using namespace fiftythree::sdk;
using fiftythree::common::static_pointer_cast;
using fiftythree::common::dynamic_pointer_cast;
using fiftythree::common::shared_ptr;
using fiftythree::common::make_shared;
using std::stringstream;

class TouchObserver;

@interface BTLECentralViewController () <FTPenDelegate, UIAlertViewDelegate, MFMailComposeViewControllerDelegate>
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
@property (nonatomic) NSString *firmwareImagePath;
@property (nonatomic) UIAlertView *firmwareUpdateConfirmAlertView;
@property (nonatomic) FTFirmwareUpdateProgressView *firmwareUpdateProgressView;
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

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(penManagerFirmwareUpdateDidBegin:)
                                                 name:kFTPenManagerFirmwareUpdateDidBegin
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(penManagerFirmwareUpdateDidBeginSendingUpdate:)
                                                 name:kFTPenManagerFirmwareUpdateDidBeginSendingUpdate
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(penManagerFirmwareUpdateDidUpdatePercentComplete:)
                                                 name:kFTPenManagerFirmwareUpdateDidUpdatePercentComplete
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(penManagerFirmwareUpdateDidFinishSendingUpdate:)
                                                 name:kFTPenManagerFirmwareUpdateDidFinishSendingUpdate
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(penManagerFirmwareUpdateWasCancelled:)
                                                 name:kFTPenManagerFirmwareUpdateWasCancelled
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(penManagerFirmwareUpdateDidCompleteSuccessfully:)
                                                 name:kFTPenManagerFirmwareUpdateDidCompleteSuccessfully
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(penManagerDidUpdateState:)
                                                 name:kFTPenManagerDidUpdateStateNotificationName
                                               object:nil];

    self.view.multipleTouchEnabled = YES;

    _PenAndTouchManager = FTPenAndTouchManager::New();
    _PenAndTouchManager->RegisterForEvents();
    _EventLogger = FTTouchEventLogger::New();
    _PenAndTouchManager->SetLogger(_EventLogger);

    _TouchObserver = make_shared<TouchObserver>(self);
    _PenAndTouchManager->TouchTypeChanged().AddListener(_TouchObserver, &TouchObserver::TouchTypeChanged);
    _PenAndTouchManager->ShouldStartTrialSeparation().AddListener(_TouchObserver, &TouchObserver::ShouldStartTrialSeparation);

    _penManager = [[FTPenManager alloc] init];
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

- (void)applicationWillEnterForeground:(NSNotification *)notification
{
}

#pragma mark - FTPenManager notifications

- (void)penManagerDidUpdateState:(NSNotification *)notification
{
    FTPenManager *penManager = notification.object;
    if (penManager.state == FTPenManagerStateUnpaired)
    {
        _PenAndTouchManager->SetPalmRejectionEnabled(false);
    }
    else if (penManager.state == FTPenManagerStateDisconnected)
    {
        _PenAndTouchManager->SetPalmRejectionEnabled(false);
    }
    else if (penManager.state == FTPenManagerStateConnecting ||
             penManager.state == FTPenManagerStateReconnecting)
    {
        NSAssert(penManager.pen, @"Pen is non-nil");

        penManager.pen.delegate = self;
    }
    else if (FTPenManagerStateIsConnected(penManager.state))
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
    }

    [self updateDisplay];
}

#pragma mark - Firmware Update

- (void)penManagerFirmwareUpdateDidBegin:(NSNotification *)notification
{
    [self.firmwareUpdateProgressView dismiss];
    self.firmwareUpdateProgressView = [FTFirmwareUpdateProgressView start];
    self.firmwareUpdateProgressView.delegate = self;
}

- (void)penManagerFirmwareUpdateDidBeginSendingUpdate:(NSNotification *)notification
{
    if (self.firmwareUpdateProgressView.percentComplete != 0.f)
    {
        [self.firmwareUpdateProgressView dismiss];
        self.firmwareUpdateProgressView = [FTFirmwareUpdateProgressView start];
        self.firmwareUpdateProgressView.delegate = self;
    }
}

- (void)penManagerFirmwareUpdateDidUpdatePercentComplete:(NSNotification *)notification
{
    const float percentComplete = [notification.userInfo[kFTPenManagerPercentCompleteProperty] floatValue];
    self.firmwareUpdateProgressView.percentComplete = percentComplete;
}

- (void)penManagerFirmwareUpdateDidFinishSendingUpdate:(NSNotification *)notification
{
    [self.firmwareUpdateProgressView dismiss];
    self.firmwareUpdateProgressView = nil;
}

- (void)penManagerFirmwareUpdateWasCancelled:(NSNotification *)notification
{
    [self.firmwareUpdateProgressView dismiss];
    self.firmwareUpdateProgressView = nil;
}

- (void)penManagerFirmwareUpdateDidCompleteSuccessfully:(NSNotification *)notification
{
    [self.firmwareUpdateProgressView dismiss];
    self.firmwareUpdateProgressView = nil;
}

#pragma mark - FTPenDelegate

- (void)penDidUpdateDeviceInfoProperty:(FTPen *)pen
{
    [self updateDisplay];
}

- (void)pen:(FTPen *)pen isReadyDidChange:(BOOL)isReady
{
    [self updateDisplay];
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

    [self.tipStateButton setHighlighted:isTipPressed];

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

    [self.eraserStateButton setHighlighted:isEraserPressed];

    PenEvent::Ptr event = PenEvent::New([NSProcessInfo processInfo].systemUptime,
                                        isEraserPressed ? PenEventType::PenDown : PenEventType::PenUp,
                                        PenTip::Tip2);
    _PenAndTouchManager->HandlePenEvent(event);
}

- (void)pen:(FTPen *)pen batteryLevelDidChange:(NSNumber *)batteryLevel
{

}

#pragma mark -

- (void)displayPenInfo:(FTPen *)pen
{
    NSLog(@"manufacturer = %@", pen.manufacturerName);
    NSLog(@"model number = %@", pen.modelNumber);
    NSLog(@"serial number = %@", pen.serialNumber);
    NSLog(@"firmware revision = %@", pen.firmwareRevision);
    NSLog(@"hardware revision = %@", pen.hardwareRevision);
    NSLog(@"software revision = %@", pen.softwareRevision);
    NSLog(@"system id = %@", pen.systemID);
    NSLog(@"PnPID.vendorId = %d", pen.PnPID.vendorId);
    NSLog(@"PnPID.vendorIdSource = %d", pen.PnPID.vendorIdSource);
    NSLog(@"PnPID.productId = %d", pen.PnPID.productId);
    NSLog(@"PnPID.productVersion = %d", pen.PnPID.productVersion);

    [self updateDisplay];
}

- (void)updateDisplay
{
    if (self.penManager.state == FTPenManagerStateDisconnected ||
        self.penManager.state == FTPenManagerStateUnpaired)
    {
        [self.pairingStatusLabel setText:@"Disconnected"];
    }
    else if (self.penManager.state == FTPenManagerStateConnecting)
    {
        [self.pairingStatusLabel setText:[NSString stringWithFormat:@"Connecting to %@",
                                          self.penManager.pen.name]];
    }
    else if (self.penManager.state == FTPenManagerStateConnected ||
             self.penManager.state == FTPenManagerStateConnectedLongPressToUnpair)
    {
        [self.pairingStatusLabel setText:[NSString stringWithFormat:@"Connected to %@",
                                          self.penManager.pen.name]];
    }
    else if (self.penManager.state == FTPenManagerStateUpdatingFirmware)
    {
        [self.pairingStatusLabel setText:[NSString stringWithFormat:@"Updating firmware on %@",
                                          self.penManager.pen.name]];
    }
    else
    {
        [self.pairingStatusLabel setText:@""];
    }

    if (FTPenManagerStateIsConnected(self.penManager.state))
    {
        [self.connectButton setTitle:@"Disconnect" forState:UIControlStateNormal];
        self.connectButton.hidden = NO;
        self.updateFirmwareButton.hidden = NO;
        self.trialSeparationButton.hidden = NO;
    }
    else
    {
        self.connectButton.hidden = YES;
        self.updateFirmwareButton.hidden = YES;
        self.trialSeparationButton.hidden = YES;

        self.tipStateButton.highlighted = NO;
        self.eraserStateButton.highlighted = NO;
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

    self.testConnectButton.hidden = YES;
}

- (IBAction)pairButtonPressed:(id)sender
{
    self.penManager.isPairingSpotPressed = YES;
    self.pairing = YES;
    [self updateDisplay];
}

- (IBAction)pairButtonReleased:(id)sender
{
    self.penManager.isPairingSpotPressed = NO;
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
    [self.penManager disconnect];
}

- (IBAction)unpairButtonPressed:(id)sender
{
//    [self.penManager deletePairedPen:self.penManager.pairedPen];

    [self updateDisplay];
}

- (IBAction)updateFirmwareButtonPressed:(id)sender
{
    if (!self.firmwareUpdateConfirmAlertView &&
        !self.firmwareUpdateProgressView)
    {
        if (YES)
            //        if ([self.penManager isFirmwareUpdateAvailable])
        {
            self.firmwareImagePath = [FTFirmwareManager imagePathIncludingDocumentsDir];
            if (self.firmwareImagePath)
            {
                NSString *message = [NSString stringWithFormat:@"Update firmware to version %d?",
                                     [FTFirmwareManager versionOfImageAtPath:self.firmwareImagePath]];
                self.firmwareUpdateConfirmAlertView = [[UIAlertView alloc] initWithTitle:@"Firmware Update"
                                                                                 message:message
                                                                                delegate:self
                                                                       cancelButtonTitle:@"No"
                                                                       otherButtonTitles:@"Yes", nil];
                [self.firmwareUpdateConfirmAlertView show];
            }
        }
        else
        {
            [[[UIAlertView alloc] initWithTitle:@"Firmware Is Up to Date"
                                        message:nil
                                       delegate:nil
                              cancelButtonTitle:@"OK"
                              otherButtonTitles:nil, nil] show];
        }
    }
}

- (IBAction)trialSeparationButtonPressed:(id)sender
{
    [self startTrialSeparation];
}

- (void)didDetectMultitaskingGesturesEnabled
{
    UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"Warning"
                                                        message:@"Multitasking Gestures detected. For the best experience, turn them Off in the Settings app under General"
                                                       delegate:nil
                                              cancelButtonTitle:@"Ok"
                                              otherButtonTitles:nil];
    [alertView show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView == self.firmwareUpdateConfirmAlertView)
    {
        if (buttonIndex == 1)
        {
            if (self.firmwareImagePath)
            {
                [self.penManager updateFirmware:self.firmwareImagePath];
            }
        }

        self.firmwareUpdateConfirmAlertView = nil;
    }
    else if (alertView == self.firmwareUpdateProgressView)
    {
        self.firmwareUpdateProgressView = nil;
        [self.penManager cancelFirmwareUpdate];
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

- (BOOL)shouldProcessTouches:(NSSet *)touches
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
        if (&sample == &touch->History()->front())
        {
            [self.canvasController beginStroke:sample];
        }
        else if (&sample == &touch->History()->back())
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

#pragma mark -

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
                      pen.softwareRevision, pen.systemID, 0UL,
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
