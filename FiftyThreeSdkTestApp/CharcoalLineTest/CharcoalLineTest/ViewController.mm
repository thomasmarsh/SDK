//
//  ViewController.mm
//  CharcoalLineTest
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "Common/Timer.h"
#import "FiftyThreeSdk/FTFirmwareManager.h"
#import "FiftyThreeSdk/FTFirmwareUpdateProgressView.h"
#import "FiftyThreeSdk/FTPen+Private.h"
#import "FiftyThreeSdk/FTPenManager+Private.h"
#import "FiftyThreeSdk/FTPenManager.h"
#import "RscMgr.h"
#import "ViewController.h"

@interface ViewController () <UIAlertViewDelegate,
RscMgrDelegate,
FTPenManagerDelegate,
FTPenManagerDelegatePrivate,
FTPenDelegate,
FTPenPrivateDelegate>

@property (nonatomic) RscMgr *rscManager;
@property (nonatomic) FTPenManager *penManager;
@property (nonatomic) UIAlertView *firmwareUpdateConfirmAlertView;
@property (nonatomic) FTFirmwareUpdateProgressView *firmwareUpdateProgressView;
@property (nonatomic) BOOL pairing;
@property (nonatomic) BOOL pcConnected;
@property (nonatomic) NSMutableString *commandBuffer;

@property (nonatomic) Timer::Ptr uptimeTimer;
@property (nonatomic) double lastTouchBeganTimestamp;
@property (nonatomic) double lastTouchEndedTimestamp;
@property (nonatomic) double lastTipOrEraserPressedTimestamp;
@property (nonatomic) double lastTipOrEraserReleasedTimestamp;

@end

@implementation ViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        _uptimeTimer = Timer::New();
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.

    _rscManager = [[RscMgr alloc] init];
    [_rscManager setDelegate:self];

    _penManager = [[FTPenManager alloc] initWithDelegate:self];

    NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
    self.appTitleNavItem.title = [NSString stringWithFormat:@"%@ %@ (%@)",
                                  infoDictionary[@"CFBundleDisplayName"],
                                  infoDictionary[@"CFBundleShortVersionString"],
                                  infoDictionary[@"CFBundleVersion"]];

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

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView == self.firmwareUpdateConfirmAlertView)
    {
        if (buttonIndex == 1)
        {
            NSString *firmwareImagePath = [self firmwareImagePath];

            if (firmwareImagePath)
            {
                [self.penManager updateFirmwareForPen:firmwareImagePath];
                self.firmwareUpdateProgressView = [FTFirmwareUpdateProgressView start];
                self.firmwareUpdateProgressView.delegate = self;
            }
        }

        self.firmwareUpdateConfirmAlertView = nil;
    }
    else if (alertView == self.firmwareUpdateProgressView)
    {
        self.firmwareUpdateProgressView = nil;
        [self.penManager disconnect];
    }
}

#pragma mark - FTPenManagerDelegate

- (void)penManagerDidFailToDiscoverPen:(FTPenManager *)penManager
{
    [[[UIAlertView alloc] initWithTitle:@"Pencil Not Found"
                                message:@"Ensure the battery is fully charged and try again."
                               delegate:nil
                      cancelButtonTitle:@"OK"
                      otherButtonTitles:nil, nil] show];
}

- (void)penManager:(FTPenManager *)penManager didUpdateState:(FTPenManagerState)state
{
    if (state == FTPenManagerStateConnecting ||
        state == FTPenManagerStateReconnecting)
    {
        NSAssert(penManager.pen, @"pen is non-nil");
        penManager.pen.delegate = self;
        penManager.pen.privateDelegate = self;
    }

    if (self.firmwareUpdateProgressView)
    {
        [self.firmwareUpdateProgressView dismiss];
        self.firmwareUpdateProgressView = nil;

        [[[UIAlertView alloc] initWithTitle:@"Update Failed"
                                    message:@"Firmware update failed. Please retry."
                                   delegate:nil
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil] show];
    }

    char stateChar = '\0';
    switch (state)
    {
        case FTPenManagerStateUnpaired:
            stateChar = 'u';
            break;
        case FTPenManagerStateConnecting:
            stateChar = 'c';
            break;
        case FTPenManagerStateReconnecting:
            stateChar = 'r';
            break;
        case FTPenManagerStateConnected:
            stateChar = 'C';
            break;
        case FTPenManagerStateDisconnected:
            stateChar = 'd';
            break;
        default:
            NSAssert(NO, @"Unexpected state.");
            break;
    }
    if (stateChar != '\0')
    {
        [self sendCharacter:stateChar];
    }

    [self updateDisplay];
}

#pragma mark - FTPenManagerDelegatePrivate

- (void)penManager:(FTPenManager *)manager didFinishUpdate:(NSError *)error
{
    [self.firmwareUpdateProgressView dismiss];
    self.firmwareUpdateProgressView = nil;
}

- (void)penManager:(FTPenManager *)manager didUpdatePercentComplete:(float)percent
{
    self.firmwareUpdateProgressView.percentComplete = percent;
}

#pragma mark - FTPenDelegate

- (void)penDidUpdateDeviceInfo:(FTPen *)pen
{
    [self displayPenInfo:pen];
}

- (void)pen:(FTPen *)pen isReadyDidChange:(BOOL)isReady
{
    [self updateDisplay];

    [pen readDebugProperties];
}

- (void)pen:(FTPen *)pen isTipPressedDidChange:(BOOL)isTipPressed
{
    if (isTipPressed)
    {
        self.lastTipOrEraserPressedTimestamp = self.uptimeTimer->ElapsedTimeSeconds();
    }
    else
    {
        self.lastTipOrEraserReleasedTimestamp = self.uptimeTimer->ElapsedTimeSeconds();
    }
    [self updateDeviceInfoLabel];

    self.tipStateButton.highlighted = isTipPressed;
    [self sendCharacter:isTipPressed ? 'A' : 'a'];
}

- (void)pen:(FTPen *)pen isEraserPressedDidChange:(BOOL)isEraserPressed
{
    if (isEraserPressed)
    {
        self.lastTipOrEraserPressedTimestamp = self.uptimeTimer->ElapsedTimeSeconds();
    }
    else
    {
        self.lastTipOrEraserReleasedTimestamp = self.uptimeTimer->ElapsedTimeSeconds();
    }
    [self updateDeviceInfoLabel];

    self.eraserStateButton.highlighted = isEraserPressed;
    [self sendCharacter:isEraserPressed ? 'B' : 'b'];
}

- (void)pen:(FTPen *)pen batteryLevelDidChange:(NSInteger)batteryLevel
{
    [self updateDeviceInfoLabel];
}

#pragma mark - FTPenPrivateDelegate

- (void)didWriteManufacturingID
{
    [self sendString:@"Successfully wrote Manufacturing ID."];
}

- (void)didFailToWriteManufacturingID
{
    [self reportError:@"Failed to write Manufacturing ID."];
}

- (void)didReadManufacturingID:(NSString *)manufacturingID
{
    [self sendString:[NSString stringWithFormat:@"Retrieved Manufacturing ID: \"%@\"", manufacturingID]];
}

- (void)didUpdateDeviceInfo
{
    [self updateDeviceInfoLabel];
}

- (void)didUpdateDebugProperties
{
    [self updateDeviceInfoLabel];
}

- (void)updateDeviceInfoLabel
{
    FTPen *pen = self.penManager.pen;
    int onTimeSec, onTimeHourField, onTimeMinField, onTimeSecField;

    onTimeSec  = pen.totalOnTimeSeconds;
    onTimeHourField = onTimeSec / 60 / 60;
    onTimeMinField  = (onTimeSec - (onTimeHourField * 60 * 60)) / 60;
    onTimeSecField  = onTimeSec - (onTimeHourField * 60 * 60) - (onTimeMinField *60);

    NSMutableString *deviceInfo = [NSMutableString string];
    [deviceInfo appendFormat:@"Manufacturer: %@\n", pen.manufacturerName];
    [deviceInfo appendFormat:@"SKU: %@\n", pen.modelNumber];
    [deviceInfo appendFormat:@"Serial Number: %@\n", pen.serialNumber];
    [deviceInfo appendFormat:@"Hardware Rev: %@\n", pen.hardwareRevision];
    [deviceInfo appendFormat:@"Factory Firmware Rev: %@\n", pen.firmwareRevision];
    [deviceInfo appendFormat:@"Upgrade Firmware Rev: %@\n", pen.softwareRevision];
    [deviceInfo appendFormat:@"    * currently running\n\n"];
    [deviceInfo appendFormat:@"Battery Level: %d%%\n", pen.batteryLevel];
    [deviceInfo appendFormat:@"Tip Presses: %d\n", pen.numTipPresses];
    [deviceInfo appendFormat:@"Eraser Presses: %d\n", pen.numEraserPresses];
    [deviceInfo appendFormat:@"Failed Connections: %d\n", pen.numFailedConnections];
    [deviceInfo appendFormat:@"Successful Connections: %d\n", pen.numSuccessfulConnections];
    [deviceInfo appendFormat:@"Total On Time: %d:%02d:%02d\n\n", onTimeHourField, onTimeMinField,  onTimeSecField];
    [deviceInfo appendFormat:@"Last Error ID: %d\n", pen.lastErrorCode.lastErrorID];
    [deviceInfo appendFormat:@"Last Error Value: %d\n\n", pen.lastErrorCode.lastErrorValue];

    const int kNoTouchCutoffMs = 1000;
    const int kNoPressCutoffMs = -1000;
    const int pressLatency = (int)round(1000.0 * (self.lastTipOrEraserPressedTimestamp -
                                                  self.lastTouchBeganTimestamp));
    NSString *pressLatencyStr = (pressLatency > kNoTouchCutoffMs ?
                                 @"No Touch" :
                                 (pressLatency < kNoPressCutoffMs ?
                                  @"No Tip/Eraser" :
                                  [NSString stringWithFormat:@"%d", pressLatency]));
    [deviceInfo appendFormat:@"Press Latency (ms): %@\n", pressLatencyStr];

    const int releaseLatency = (int)round(1000.0 * (self.lastTipOrEraserReleasedTimestamp -
                                                    self.lastTouchEndedTimestamp));
    NSString *releaseLatencyStr = (releaseLatency > kNoTouchCutoffMs ?
                                   @"No Touch" :
                                   (releaseLatency < kNoPressCutoffMs ?
                                    @"No Tip/Eraser" :
                                    [NSString stringWithFormat:@"%d", releaseLatency]));
    if (self.penManager.pen.isTipPressed ||
        self.penManager.pen.isEraserPressed)
    {
        releaseLatencyStr = @"";
    }
    [deviceInfo appendFormat:@"Release Latency (ms): %@\n", releaseLatencyStr];

    if (self.penManager.pen.lastErrorCode.lastErrorID != 0)
    {
        self.clearLastErrorButton.hidden = NO;
    }
    else
    {
        self.clearLastErrorButton.hidden = YES;
    }

    self.deviceInfoLabel.text = deviceInfo;
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
    if (self.penManager.state == FTPenManagerStateDisconnected ||
        self.penManager.state == FTPenManagerStateUnpaired)
    {
        [self.statusLabel setText:@"Disconnected"];
    }
    else if (self.penManager.state == FTPenManagerStateConnecting)
    {
        [self.statusLabel setText:[NSString stringWithFormat:@"Connecting to %@", self.penManager.pen.name]];
    }
    else if (self.penManager.state == FTPenManagerStateReconnecting)
    {
        [self.statusLabel setText:[NSString stringWithFormat:@"Reconnecting to %@", self.penManager.pen.name]];
    }
    else if (self.penManager.state == FTPenManagerStateConnected)
    {
        [self.statusLabel setText:[NSString stringWithFormat:@"Connected to %@", self.penManager.pen.name]];
    }

    if (self.penManager.state == FTPenManagerStateConnected)
    {
        [self.connectButton setTitle:@"Disconnect" forState:UIControlStateNormal];
        self.penConnectedButton.highlighted = YES;
        self.connectButton.hidden = NO;
        self.updateFirmwareButton.hidden = NO;
        self.updateStatsButton.hidden = NO;
    }
    else
    {
        self.penConnectedButton.highlighted = NO;
        self.connectButton.hidden = YES;
        self.updateFirmwareButton.hidden = YES;
        self.updateStatsButton.hidden = YES;
        self.clearLastErrorButton.hidden = YES;

        self.tipStateButton.highlighted = NO;
        self.eraserStateButton.highlighted = NO;

        self.deviceInfoLabel.text = @"";
    }

    [self.pcConnectedButton setHighlighted:self.pcConnected];
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

- (NSString *)firmwareImagePath
{
    return [FTFirmwareManager filePathForImageType:Upgrade];
}

- (IBAction)updateFirmwareButtonTouchUpInside:(id)sender
{
    if (!self.firmwareUpdateConfirmAlertView &&
        !self.firmwareUpdateProgressView)
    {
        NSString *firmwareUpdateImage = [self firmwareImagePath];
        if (firmwareUpdateImage)
        {
            NSString *message = [NSString stringWithFormat:@"Update with the following image?\n\n%@",
                                 [firmwareUpdateImage lastPathComponent]];
            self.firmwareUpdateConfirmAlertView = [[UIAlertView alloc] initWithTitle:@"Update Firmware"
                                                                             message:message
                                                                            delegate:self
                                                                   cancelButtonTitle:@"No"
                                                                   otherButtonTitles:@"Yes", nil];
            [self.firmwareUpdateConfirmAlertView show];
        }
    }
}

- (IBAction)clearLastErrorButtonTouchUpInside:(id)sender
{
    [self.penManager.pen clearLastErrorCode];
}

- (IBAction)updateStatsTouchUpInside:(id)sender
{
    [self.penManager.pen readDebugProperties];
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
    if (self.penManager.pen)
    {
        [self.penManager disconnect];
    }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    self.lastTouchBeganTimestamp = self.uptimeTimer->ElapsedTimeSeconds();
    [self updateDeviceInfoLabel];

    [self sendCharacter:'T'];
    [self.touchButton setHighlighted:YES];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{

}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    self.lastTouchEndedTimestamp = self.uptimeTimer->ElapsedTimeSeconds();
    [self updateDeviceInfoLabel];

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
    if (!self.commandBuffer)
    {
        self.commandBuffer = [NSMutableString string];
    }

    NSString *input = [self.rscManager getStringFromBytesAvailable];

    // Echo received (typed) chars back to serial port (terminal user)
    [self.rscManager write:(UInt8 *)input.UTF8String length:input.length];

    // Remove all CRs from the input
    input = [input stringByReplacingOccurrencesOfString:@"\r" withString:@""];

    [self.commandBuffer appendFormat:@"%@", input];

    [self parseCommandBuffer];
}

#pragma mark - Serial Connection Commands

- (void)parseCommandBuffer
{
    NSArray *commands = [self.commandBuffer componentsSeparatedByString:@"\n"];

    if ([commands[0] isEqualToString:self.commandBuffer])
    {
        return;
    }

    if ([commands[commands.count - 1] isEqualToString:@""])
    {
        self.commandBuffer = nil;
    }
    else
    {
        self.commandBuffer = [NSMutableString stringWithString:commands[commands.count - 1]];
        commands = [commands subarrayWithRange:NSMakeRange(0, commands.count - 1)];
    }

    if (commands.count > 0)
    {
        for (NSString *command in commands)
        {
            if (![command isEqualToString:@""])
            {
                [self executeCommand:command];
            }
        }
    }
}

- (void)executeCommand:(NSString *)command
{
    if ([command canBeConvertedToEncoding:NSASCIIStringEncoding])
    {
        NSString * const kSetIdCommandPrefix = @"set id ";
        NSString * const kGetIdCommand = @"get id";
        NSString * const kGetBatteryLevelCommand = @"get battery";
        static const int kIdLength = 15;

        if (self.penManager.state != FTPenManagerStateConnected)
        {
            [self reportError:@"Pen not connected."];
            return;
        }

        if ([command hasPrefix:kSetIdCommandPrefix])
        {
            if (command.length == kSetIdCommandPrefix.length + kIdLength)
            {
                NSString *manufacturingID = [command substringWithRange:NSMakeRange(command.length - kIdLength,
                                                                                    kIdLength)];

                self.penManager.pen.manufacturingID = manufacturingID;
                [self sendString:[NSString stringWithFormat:@"Set Manufacturing ID: \"%@\"",
                                  manufacturingID]];
            }
            else
            {
                [self reportError:@"Invalid ID length."];
            }
        }
        else if ([command isEqualToString:kGetIdCommand])
        {
            if (self.penManager.state == FTPenManagerStateConnected)
            {
                [self.penManager.pen readDebugProperties];
            }
        }
        else if ([command isEqualToString:kGetBatteryLevelCommand])
        {
            NSString *result = [NSString stringWithFormat:@"Battery level: %d%%",
                                self.penManager.pen.batteryLevel];
            [self sendString:result];
        }
        else
        {
            [self reportError:[NSString stringWithFormat:@"Unknown command: \"%@\".",
                               command]];
        }
    }
    else
    {
        [self reportError:@"Non-ASCII character encountered."];
    }
}

- (void)sendCharacter:(uint8_t)c
{
    if (self.pcConnected)
    {
        [self.rscManager write:&c length:sizeof(c)];
    }
}

- (void)sendString:(NSString *)string
{
    NSAssert([string canBeConvertedToEncoding:NSASCIIStringEncoding], @"String must be ASCII");

    if (self.pcConnected)
    {
        NSString *newlineTerminatedString = [string stringByAppendingString:@"\r\n"];

        [self.rscManager write:(UInt8 *)newlineTerminatedString.UTF8String
                        length:newlineTerminatedString.length];
    }
}

- (void)reportError:(NSString *)description
{
    [self sendString:[NSString stringWithFormat:@"ERROR: %@", description]];
}

@end
