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

@interface BTLECentralViewController () <FTPenManagerDelegate, FTPenDelegate, FTPenManagerDelegatePrivate, UIAlertViewDelegate>

@property (nonatomic) FTPenManager *penManager;
@property (nonatomic) id currentTest;
@property (nonatomic) UIAlertView *updateAlertView;

@end

@implementation BTLECentralViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.

    _penManager = [[FTPenManager alloc] initWithDelegate:self];
    while (!_penManager.isReady) {}

    [self.testConnectButton setHidden:YES];
    [self updateDisplay];
}

- (void)viewWillAppear:(BOOL)animated
{
    [_penManager registerView:self.view];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [_penManager deregisterView:self.view];
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
    NSLog(@"hw revision = %@", pen.hardwareRevision);
    NSLog(@"sw revision = %@", pen.softwareRevision);
    NSLog(@"system id = %@", pen.systemId);
    NSLog(@"pnp id = %@", pen.pnpId);
    NSLog(@"certification data = %@", pen.certificationData);
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
    
    self.updateAlertView.message = [NSString stringWithFormat:@"%.1f%% Complete", percent];
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

    if (self.penManager.pairedPen)
    {
        [self.testConnectButton setHidden:NO];
        [self.connectButton setHidden:NO];
        [self.disconnectButton setHidden:NO];
        [self.unpairButton setHidden:NO];
        [self.updateFirmwareButton setHidden:NO];
    }
    else
    {
        [self.testConnectButton setHidden:YES];
        [self.connectButton setHidden:YES];
        [self.disconnectButton setHidden:YES];
        [self.unpairButton setHidden:YES];
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
    [self.penManager connect];
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
    self.updateAlertView = [[UIAlertView alloc] initWithTitle:@"Firmware Update" message:@"0% Complete" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:nil, nil];
    [self.updateAlertView show];
    
    [self.penManager updateFirmware:[[NSBundle mainBundle] pathForResource:@"charcoal" ofType:@"img"] forPen:self.penManager.connectedPen];
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

@end
