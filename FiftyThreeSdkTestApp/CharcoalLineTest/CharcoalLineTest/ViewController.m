//
//  ViewController.m
//  CharcoalLineTest
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "ViewController.h"
#import "RscMgr.h"
#import "FiftyThreeSdk/FTPenManager.h"

@interface ViewController () <RscMgrDelegate, FTPenManagerDelegate, FTPenDelegate>

@property (nonatomic) RscMgr *rscManager;
@property (nonatomic) FTPenManager *penManager;
@property (nonatomic) BOOL pairing;
@property (nonatomic) BOOL pcConnected;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.

    _rscManager = [[RscMgr alloc] init];
    [_rscManager setDelegate:self];

    _penManager = [[FTPenManager alloc] initWithDelegate:self];
    _penManager.autoConnect = NO;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self updateDisplay];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - FTPenManagerDelegate

- (void)penManagerDidUpdateState:(FTPenManager *)penManager
{
    [self updateDisplay];
}

- (void)penManager:(FTPenManager *)penManager didPairWithPen:(FTPen *)pen
{
    NSLog(@"didPairWithPen name=%@", pen.name);

    [self updateDisplay];
}

- (void)penManager:(FTPenManager *)penManager didUnpairFromPen:(FTPen *)pen
{
    NSLog(@"didUnpairFromPen name=%@", pen.name);

    [self updateDisplay];
}

- (void)penManager:(FTPenManager *)penManager didConnectToPen:(FTPen *)pen
{
    NSLog(@"didConnectToPen name=%@", pen.name);

    pen.delegate = self;

    [self updateDisplay];
}

- (void)penManager:(FTPenManager *)penManager didFailConnectToPen:(FTPen *)pen
{
    NSLog(@"didFailConnectToPen name=%@", pen.name);

    [self updateDisplay];
}

- (void)penManager:(FTPenManager *)penManager didDisconnectFromPen:(FTPen *)pen
{
    NSLog(@"didDisconnectFromPen name=%@", pen.name);

    [self updateDisplay];
}

- (void)penManager:(FTPenManager *)penManager didUpdateDeviceInfo:(FTPen *)pen
{
    [self displayPenInfo:pen];
}

- (void)sendCharacter:(uint8_t)c
{
    if (self.pcConnected)
    {
        [self.rscManager write:&c Length:sizeof(c)];
    }
}

#pragma mark - FTPenDelegate

- (void)pen:(FTPen *)pen isReadyDidChange:(BOOL)isReady
{
    [self updateDisplay];
}

- (void)pen:(FTPen *)pen isTipPressedDidChange:(BOOL)isTipPressed
{
    self.tip1State.highlighted = isTipPressed;
    [self sendCharacter:isTipPressed ? 'A' : 'a'];
}

- (void)pen:(FTPen *)pen isEraserPressedDidChange:(BOOL)isEraserPressed
{
    self.tip2State.highlighted = isEraserPressed;
    [self sendCharacter:isEraserPressed ? 'B' : 'b'];
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

#pragma mark -

- (void)updateDisplay
{
    if (self.penManager.pen)
    {
        if (self.penManager.pen.isReady)
        {
            [self.statusLabel setText:[NSString stringWithFormat:@"Connected to %@", self.penManager.pen.name]];
        }
        else
        {
            [self.statusLabel setText:[NSString stringWithFormat:@"Connecting to %@", self.penManager.pen.name]];
        }
    }
    else
    {
        [self.statusLabel setText:@"Disconnected"];
    }

    if (self.penManager.pen)
    {
        [self.connectButton setTitle:@"Disconnect" forState:UIControlStateNormal];
//        [self.updateFirmwareButton setHidden:NO];
    }
    else
    {
        [self.connectButton setTitle:@"Connect" forState:UIControlStateNormal];

        [self.tip1State setHighlighted:NO];
        [self.tip2State setHighlighted:NO];
    }

    [self.pcConnectedButton setHighlighted:!self.pcConnected];
    [self.penConnectedButton setHighlighted:!self.penManager.pen];
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

- (IBAction)connectButtonPressed:(id)sender
{
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
                      \n",
                      pen.manufacturerName,
                      pen.modelNumber,
                      pen.serialNumber,
                      pen.firmwareRevision,
                      pen.hardwareRevision,
                      pen.softwareRevision,
                      pen.systemID,
                      0UL];

    UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"Device Information" message:info delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
    [alertView show];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self sendCharacter:'T'];
    [self.touchButton setHighlighted:YES];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{

}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self sendCharacter:'t'];
    [self.touchButton setHighlighted:NO];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{

}

#pragma mark -
#pragma mark RSC delegate

// Redpark Serial Cable has been connected and/or application moved to foreground.
// protocol is the string which matched from the protocol list passed to initWithProtocol:
- (void)cableConnected:(NSString *)protocol
{
    [self.rscManager open];

    self.pcConnected = YES;
    [self updateDisplay];
}

// Redpark Serial Cable was disconnected and/or application moved to background
- (void)cableDisconnected
{
    self.pcConnected = NO;
    [self updateDisplay];
}

// serial port status has changed
// user can call getModemStatus or getPortStatus to get current state
- (void)portStatusChanged
{

}

// bytes are available to be read (user should call read:, getDataFromBytesAvailable, or getStringFromBytesAvailable)
- (void)readBytesAvailable:(UInt32)length
{

}

@end
