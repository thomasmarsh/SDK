//
//  ViewController.mm
//  CharcoalLineTest
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import <Security/Security.h>

#import "Common/DeviceInfo.h"
#import "Common/NSData+Crypto.h"
#import "Common/NSString+Helpers.h"
#import "Common/Timer.h"
#import "Common/UIView+Helpers.h"
#import "FiftyThreeSdk/FTFirmwareManager.h"
#import "FiftyThreeSdk/FTFirmwareUpdateProgressView.h"
#import "FiftyThreeSdk/FTLog.h"
#import "FiftyThreeSdk/FTPen+Private.h"
#import "FiftyThreeSdk/FTPenManager+Private.h"
#import "FiftyThreeSdk/FTPenManager.h"
#import "KeychainItemWrapper/KeychainItemWrapper.h"
#import "RscMgr.h"
#import "UIALertView-Blocks/UIAlertView+Blocks.h"
#import "ViewController.h"

NSString *applicationDocumentsDirectory()
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    return basePath;
}

using namespace fiftythree::common;

@interface ViewController () <UIAlertViewDelegate,
RscMgrDelegate,
FTPenDelegate,
FTPenPrivateDelegate>

@property (nonatomic) RscMgr *rscManager;
@property (nonatomic) FTPenManager *penManager;
@property (nonatomic) UIAlertView *firmwareUpdateConfirmAlertView;
@property (nonatomic) FTFirmwareUpdateProgressView *firmwareUpdateProgressView;
@property (nonatomic) BOOL pairing;
@property (nonatomic) BOOL isPCConnected;
@property (nonatomic) NSMutableString *commandBuffer;

@property (nonatomic) NSString *firmwareImagePath;
@property (nonatomic) Timer::Ptr uptimeTimer;
@property (nonatomic) __weak UITouch *currentTouch;
@property (nonatomic) double lastTouchBeganTimestamp;
@property (nonatomic) double lastTouchEndedTimestamp;
@property (nonatomic) double lastTipOrEraserPressedTimestamp;
@property (nonatomic) double lastTipOrEraserReleasedTimestamp;

@property (nonatomic) int numUnexpectedDisconnectsGeneral;
@property (nonatomic) int numUnexpectedDisconnectsConnecting;
@property (nonatomic) int numUnexpectedDisconnectsFirmware;

@property (nonatomic) KeychainItemWrapper *PKCS12PasswordKeychainItem;
@property (nonatomic) SecIdentityRef authenticationCodeSigningIdentity;
@property (nonatomic) SecKeyRef authenticationCodeSigningPublicKey;

@end

@implementation ViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        _uptimeTimer = Timer::New();

        _PKCS12PasswordKeychainItem = [[KeychainItemWrapper alloc] initWithIdentifier:@"com.fiftythree.pencil.PKCS12Password"
                                                                          accessGroup:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(penIsReady:)
                                                     name:kFTPenIsReadyDidChangeNotificationName
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(penDidEncounterUnexpectedDisconnect:)
                                                     name:kFTPenUnexpectedDisconnectNotificationName
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(penDidEncounterUnexpectedDisconnectWhileConnecting:)
                                                     name:kFTPenUnexpectedDisconnectWhileConnectingNotifcationName
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(penDidEncounterUnexpectedDisconnectWhileUpdatingFirmware:)
                                                     name:kFTPenUnexpectedDisconnectWhileUpdatingFirmwareNotificationName
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(penDidUpdatePrivateProperties:)
                                                     name:kFTPenDidUpdatePrivatePropertiesNotificationName
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
                                                 selector:@selector(penManagerDidFailToDiscoverPen:)
                                                     name:kFTPenManagerDidFailToDiscoverPenNotificationName
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(penManagerDidUpdateState:)
                                                     name:kFTPenManagerDidUpdateStateNotificationName
                                                   object:nil];
    }

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    _rscManager = [[RscMgr alloc] init];
    [_rscManager setDelegate:self];

//    [FTLog setLogLevel:FTLogLevelEnabledVerbose];
    _penManager = [[FTPenManager alloc] init];

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

#pragma mark - Notifications

- (void)penIsReady:(NSNotification *)notification
{
    if (self.penManager.pen.isReady)
    {
        [self.penManager.pen readUsageProperties];
    }
}

- (void)penDidEncounterUnexpectedDisconnect:(NSNotification *)notification
{
    self.numUnexpectedDisconnectsGeneral++;
    [self updateConnectionHistoryLabel];
}

- (void)penDidEncounterUnexpectedDisconnectWhileConnecting:(NSNotification *)notification
{
    self.numUnexpectedDisconnectsConnecting++;
    [self updateConnectionHistoryLabel];
}

- (void)penDidEncounterUnexpectedDisconnectWhileUpdatingFirmware:(NSNotification *)notification
{
    self.numUnexpectedDisconnectsFirmware++;
    [self updateConnectionHistoryLabel];
}

- (void)penDidUpdatePrivateProperties:(NSNotification *)notification
{
    [self updateDisplay];
}

#pragma mark - UIAlertViewDelegate

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
}

#pragma mark - FTPenManager notifications

- (void)penManagerDidFailToDiscoverPen:(NSNotification *)notification
{
    [self.statusLabel setText:@"Pencil not found. Ensure the battery is fully charged and try again."];
}

- (void)penManagerDidUpdateState:(NSNotification *)notification
{
    FTPenManager *penManager = notification.object;
    if (penManager.state == FTPenManagerStateConnecting ||
        penManager.state == FTPenManagerStateReconnecting)
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
    switch (penManager.state)
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
        case FTPenManagerStateUninitialized:
        case FTPenManagerStateSeeking:
        case FTPenManagerStateUpdatingFirmware:
        case FTPenManagerStateConnectedLongPressToUnpair:
        case FTPenManagerStateDisconnectedLongPressToUnpair:
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
    [self updateDeviceInfoLabel];
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
    [self updateConnectionHistoryLabel];

    [self sendCharacter:isTipPressed ? 'A' : 'a'];

    [self updateIsPressedLabels];
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
    [self updateConnectionHistoryLabel];

    [self sendCharacter:isEraserPressed ? 'B' : 'b'];

    [self updateIsPressedLabels];
}

- (void)pen:(FTPen *)pen tipPressureDidChange:(float)tipPressure
{
//    NSLog(@"tip pressure: %f", tipPressure);
}

- (void)pen:(FTPen *)pen eraserPressureDidChange:(float)eraserPressure
{
//    NSLog(@"eraser pressure: %f", eraserPressure);
}

- (void)pen:(FTPen *)pen batteryLevelDidChange:(NSNumber *)batteryLevel
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
    [self sendString:[NSString stringWithFormat:@"Retrieved Manufacturing ID: \"%@\"",
                      manufacturingID]];
}

- (void)didWriteAuthenticationCode
{
    [self sendString:@"Successfully wrote Authentication Code."];
}

- (void)didFailToWriteAuthenticationCode
{
    [self reportError:@"Failed to write Authentication Code."];
}

- (void)didReadAuthenticationCode:(NSData *)authenticationCode
{
    [self sendString:[NSString stringWithFormat:@"Retrieved Authentication Code: \"%@\"",
                      authenticationCode]];
}

- (void)didUpdateDeviceInfo
{
    [self updateDeviceInfoLabel];
}

- (void)didUpdateUsageProperties:(NSSet *)updatedProperties
{
    [self updateDeviceInfoLabel];
}

#pragma mark -

- (void)updateIsPressedLabels
{
    // Tip
    [self setIsPressed:self.penManager.pen.isTipPressed
     forIsPressedLabel:self.isTipPressedLabel
          pressedColor:[UIColor greenColor]];

    // Eraser
    [self setIsPressed:self.penManager.pen.isEraserPressed
     forIsPressedLabel:self.isEraserPressedLabel
          pressedColor:[UIColor blueColor]];

    // Touch
    [self setIsPressed:(self.currentTouch != nil)
     forIsPressedLabel:self.isTouchPressedLabel
          pressedColor:[UIColor cyanColor]];
}

- (void)setIsPressed:(BOOL)isPressed forIsPressedLabel:(UILabel *)label pressedColor:(UIColor *)pressedColor
{
    if (isPressed)
    {
        label.textColor = [UIColor lightGrayColor];
        [label setBackgroundColor:pressedColor];
    }
    else
    {
        label.textColor = [UIColor blackColor];
        label.backgroundColor = [UIColor whiteColor];
    }
}

- (void)updateIsConnectedLabels
{
    // Is PC Connected
    [self setIsConnected:self.isPCConnected forIsConnectedLabel:self.isPCConnectedLabel];

    // Is pen connected
    [self setIsConnected:FTPenManagerStateIsConnected(self.penManager.state)
     forIsConnectedLabel:self.isPenConnectedLabel];
}

- (void)setIsConnected:(BOOL)isConnected forIsConnectedLabel:(UILabel *)label
{
    if (isConnected)
    {
        label.textColor = [UIColor whiteColor];
        [label setBackgroundColor:[UIColor purpleColor]];
    }
    else
    {
        label.textColor = [UIColor blackColor];
        label.backgroundColor = [UIColor whiteColor];
    }
}

- (void)updateConnectionHistoryLabel
{
    NSMutableString *connectionHistory = [NSMutableString string];
    [connectionHistory appendFormat:@"Disconnects\n"];
    [connectionHistory appendFormat:@"    General: %d\n", self.numUnexpectedDisconnectsGeneral];
    [connectionHistory appendFormat:@"    Connecting: %d\n", self.numUnexpectedDisconnectsConnecting];
    [connectionHistory appendFormat:@"    Firmware: %d\n\n", self.numUnexpectedDisconnectsFirmware];

    const int kNoTouchCutoffMs = 1000;
    const int kNoPressCutoffMs = -1000;
    const int pressLatency = (int)round(1000.0 * (self.lastTipOrEraserPressedTimestamp -
                                                  self.lastTouchBeganTimestamp));
    NSString *pressLatencyStr = (pressLatency > kNoTouchCutoffMs ?
                                 @"No Touch" :
                                 (pressLatency < kNoPressCutoffMs ?
                                  @"No Tip/Eraser" :
                                  [NSString stringWithFormat:@"%d", pressLatency]));
    [connectionHistory appendFormat:@"Press Latency (ms): %@\n", pressLatencyStr];

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
    [connectionHistory appendFormat:@"Release Latency (ms): %@\n", releaseLatencyStr];

    self.connectionHistoryLabel.text = connectionHistory;
    self.connectionHistoryLabel.size = [self.connectionHistoryLabel sizeThatFits:CGSizeZero];
    [self.connectionHistoryLabel.superview setNeedsLayout];
}

- (NSString *)postProcessHardwareRevision:(NSString *)hardwareRevision
{
    // Due to some esoteric intricacies of the HW/FW combo, we don't accurately report hardwareRevision
    // on some units. This should clear it up.
    if ([hardwareRevision isEqualToString:@"DV1"])
    {
        return @"DV/PV";
    }
    else if ([hardwareRevision isEqualToString:@"Unknown"])
    {
        return @"MP";
    }
    return hardwareRevision;
}

- (void)updateDeviceInfoLabel
{
    if (!FTPenManagerStateIsConnected(self.penManager.state))
    {
        self.deviceInfoLabel.text = @"";
        return;
    }

    FTPen *pen = self.penManager.pen;

    NSMutableString *deviceInfo = [NSMutableString string];
    [deviceInfo appendFormat:@"Manufacturer: %@\n", pen.manufacturerName];
    [deviceInfo appendFormat:@"SKU: %@\n", pen.modelNumber];
    [deviceInfo appendFormat:@"Serial Number: %@\n", pen.serialNumber];
    [deviceInfo appendFormat:@"Hardware Rev: %@\n", [self postProcessHardwareRevision:pen.hardwareRevision]];
    [deviceInfo appendFormat:@"Factory Firmware Rev: %@\n", pen.firmwareRevision];
    [deviceInfo appendFormat:@"Upgrade Firmware Rev: %@\n", pen.softwareRevision];
    [deviceInfo appendFormat:@"    * currently running\n\n"];

    NSString *batteryLevelText = @"Battery Level:\n\n";
    if (pen.batteryLevel)
    {
        batteryLevelText = [NSString stringWithFormat:@"Battery Level: %d%%\n\n", pen.batteryLevel.integerValue];
    }
    int batteryLevelOffset = [deviceInfo length];
    [deviceInfo appendString:batteryLevelText];

    [deviceInfo appendFormat:@"Tip Presses: %d\n", pen.numTipPresses];
    [deviceInfo appendFormat:@"Eraser Presses: %d\n", pen.numEraserPresses];
    [deviceInfo appendFormat:@"Failed Connections: %d\n", pen.numFailedConnections];
    [deviceInfo appendFormat:@"Successful Connections: %d\n", pen.numSuccessfulConnections];
//    [deviceInfo appendFormat:@"Num Resets: %d\n", pen.numResets];
//    [deviceInfo appendFormat:@"Num Link Terminations: %d\n", pen.numLinkTerminations];
//    [deviceInfo appendFormat:@"Num Dropped Notifications: %d\n", pen.numDroppedNotifications];
    [deviceInfo appendFormat:@"Total Connected Time: %@\n\n",
     [NSString stringWithTimeInterval:pen.connectedSeconds]];

//    [deviceInfo appendFormat:@"Last Error ID: %d\n",
//     (pen.lastErrorCode ? pen.lastErrorCode.lastErrorID : - 1)];
//    [deviceInfo appendFormat:@"Last Error Value: %d\n\n",
//     (pen.lastErrorCode ? pen.lastErrorCode.lastErrorValue : -1)];
//
//    if (pen.inactivityTimeout == 0)
//    {
//        [deviceInfo appendFormat:@"Inactivity Timeout: Never\n\n"];
//    }
//    else
//    {
//        [deviceInfo appendFormat:@"Inactivity Timeout: %d\n\n", pen.inactivityTimeout];
//    }
//
//    if (pen.pressureSetup)
//    {
//        [deviceInfo appendFormat:@"Pressure Rate: %d %d\n",
//         pen.pressureSetup.samplePeriodMilliseconds,
//         pen.pressureSetup.notificatinPeriodMilliseconds];
//
//        [deviceInfo appendFormat:@"Tip Mapping: %d %d %d %d\n",
//         pen.pressureSetup.tipFloorThreshold,
//         pen.pressureSetup.tipMinThreshold,
//         pen.pressureSetup.tipMaxThreshold,
//         pen.pressureSetup.isTipGated];
//
//        [deviceInfo appendFormat:@"Eraser Mapping: %d %d %d %d\n",
//         pen.pressureSetup.eraserFloorThreshold,
//         pen.pressureSetup.eraserMinThreshold,
//         pen.pressureSetup.eraserMaxThreshold,
//         pen.pressureSetup.isEraserGated];
//    }
//    else
//    {
//        [deviceInfo appendFormat:@"Tip Pressure Setup:\n"];
//        [deviceInfo appendFormat:@"Eraser Pressure Setup:\n"];
//    }

    if (self.penManager.pen.lastErrorCode.lastErrorID != 0)
    {
//        self.clearLastErrorButton.hidden = NO;
    }
    else
    {
        self.clearLastErrorButton.hidden = YES;
    }

    UIColor *batteryLevelColor = [UIColor blackColor];
    if (pen.batteryLevel)
    {
        batteryLevelColor = (pen.batteryLevel.integerValue < 50 ?
                             [UIColor redColor] :
                             [UIColor greenColor]);
    }

    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:deviceInfo];
    [attributedString addAttribute:NSForegroundColorAttributeName
                             value:batteryLevelColor
                             range:NSMakeRange(batteryLevelOffset, [batteryLevelText length])];

    self.deviceInfoLabel.attributedText = attributedString;
    self.deviceInfoLabel.size = [self.deviceInfoLabel sizeThatFits:CGSizeZero];
    [self.deviceInfoLabel.superview setNeedsLayout];
}

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

    switch (self.penManager.state)
    {
        case FTPenManagerStateUninitialized:
            [self.statusLabel setText:@"Uninitialized"];
            break;
        case FTPenManagerStateUpdatingFirmware:
            [self.statusLabel setText:[NSString stringWithFormat:@"Updating firmware on %@",
                                       self.penManager.pen.name]];
            break;
        case FTPenManagerStateUnpaired:
            [self.statusLabel setText:@"Unpaired"];
            break;
        case FTPenManagerStateSeeking:
            [self.statusLabel setText:@"Seeking"];
            break;
        case FTPenManagerStateConnecting:
            [self.statusLabel setText:[NSString stringWithFormat:@"Connecting to %@",
                                       self.penManager.pen.name]];
            break;
        case FTPenManagerStateReconnecting:
            [self.statusLabel setText:[NSString stringWithFormat:@"Reconnecting to %@",
                                       self.penManager.pen.name]];
            break;
        case FTPenManagerStateConnected:
            [self.statusLabel setText:[NSString stringWithFormat:@"Connected to %@",
                                       self.penManager.pen.name]];
            break;
        case FTPenManagerStateConnectedLongPressToUnpair:
            [self.statusLabel setText:[NSString stringWithFormat:@"*Connected to %@",
                                       self.penManager.pen.name]];
            break;
        case FTPenManagerStateDisconnected:
            [self.statusLabel setText:@"Disconnected"];
            break;
        case FTPenManagerStateDisconnectedLongPressToUnpair:
            [self.statusLabel setText:@"*Disconnected"];
            break;
        default:
            NSAssert(NO, @"unexpected state");
            break;
    }

    if (FTPenManagerStateIsConnected(self.penManager.state))
    {
        [self.connectButton setTitle:@"Disconnect" forState:UIControlStateNormal];
        self.connectButton.hidden = NO;
        self.updateFirmwareButton.hidden = NO;
        self.updateStatsButton.hidden = NO;
//        self.incrementInactivityTimeoutButton.hidden = NO;
//        self.decrementInactivityTimeoutButton.hidden = NO;
//        self.togglePressureButton.hidden = NO;
    }
    else
    {
        self.connectButton.hidden = YES;
        self.updateFirmwareButton.hidden = YES;
        self.updateStatsButton.hidden = YES;
        self.incrementInactivityTimeoutButton.hidden = YES;
        self.decrementInactivityTimeoutButton.hidden = YES;
        self.togglePressureButton.hidden = YES;
        self.clearLastErrorButton.hidden = YES;
    }

    [self updateIsConnectedLabels];
    [self updateIsPressedLabels];
    [self updateDeviceInfoLabel];
    [self updateConnectionHistoryLabel];
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

- (IBAction)updateFirmwareButtonTouchUpInside:(id)sender
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

- (IBAction)clearLastErrorButtonTouchUpInside:(id)sender
{
    [self.penManager.pen clearLastErrorCode];
}

- (IBAction)updateStatsTouchUpInside:(id)sender
{
    [self.penManager.pen readUsageProperties];
}

- (IBAction)incrementInactivityTimeoutButtonTouchUpInside:(id)sender
{
    self.penManager.pen.inactivityTimeout++;
}

- (IBAction)decrementInactivityTimeoutButtonTouchUpInside:(id)sender
{
    if (self.penManager.pen.inactivityTimeout > 0)
    {
        self.penManager.pen.inactivityTimeout--;
    }
}

- (IBAction)togglePressureButtonTouchUpInside:(id)sender
{
    if (self.penManager.pen.pressureSetup)
    {
        if (self.penManager.pen.pressureSetup.samplePeriodMilliseconds > 0)
        {
            self.penManager.pen.pressureSetup = [[FTPenPressureSetup alloc] initWithSamplePeriodMilliseconds:0
                                                                               notificatinPeriodMilliseconds:0
                                                                                           tipFloorThreshold:0
                                                                                             tipMinThreshold:0
                                                                                             tipMaxThreshold:0
                                                                                                  isTipGated:NO
                                                                                        eraserFloorThreshold:0
                                                                                          eraserMinThreshold:0
                                                                                          eraserMaxThreshold:0
                                                                                               isEraserGated:NO];
        }
        else
        {
            self.penManager.pen.pressureSetup = [[FTPenPressureSetup alloc] initWithSamplePeriodMilliseconds:20
                                                                               notificatinPeriodMilliseconds:100
                                                                                           tipFloorThreshold:32
                                                                                             tipMinThreshold:128
                                                                                             tipMaxThreshold:255
                                                                                                  isTipGated:NO
                                                                                        eraserFloorThreshold:32
                                                                                          eraserMinThreshold:128
                                                                                          eraserMaxThreshold:255
                                                                                               isEraserGated:NO];
        }
    }
}

- (IBAction)clearStatusButtonTouchUpInside:(id)sender
{
    self.numUnexpectedDisconnectsGeneral = 0;
    self.numUnexpectedDisconnectsConnecting = 0;
    self.numUnexpectedDisconnectsFirmware = 0;
    [self updateConnectionHistoryLabel];
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
    NSAssert(touches.count == 1, @"Should be only a single touch.");
    NSAssert(!self.currentTouch, @"Should only be a single touch at a time.");

    self.lastTouchBeganTimestamp = self.uptimeTimer->ElapsedTimeSeconds();
    [self updateConnectionHistoryLabel];

    [self sendCharacter:'T'];

    self.currentTouch = [touches anyObject];
    [self updateIsPressedLabels];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    NSAssert(touches.count == 1, @"Should be only a single touch.");
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    NSAssert(touches.count == 1, @"Should be only a single touch.");
    NSAssert(self.currentTouch, @"touch non-nil");

    self.lastTouchEndedTimestamp = self.uptimeTimer->ElapsedTimeSeconds();
    [self updateDeviceInfoLabel];

    [self sendCharacter:'t'];

    self.currentTouch = nil;
    [self updateIsPressedLabels];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    NSAssert(touches.count == 1, @"Should be only a single touch.");
    NSAssert(self.currentTouch, @"touch non-nil");

    self.currentTouch = nil;
    [self updateIsPressedLabels];
}

#pragma mark -
#pragma mark RSC delegate

// Redpark Serial Cable has been connected and/or application moved to foreground.
// protocol is the string which matched from the protocol list passed to initWithProtocol:
- (void)cableConnected:(NSString *)protocol
{
    [self.rscManager open];

    self.isPCConnected = YES;
    [self updateIsConnectedLabels];
}

// Redpark Serial Cable was disconnected and/or application moved to background
- (void)cableDisconnected
{
    self.isPCConnected = NO;
    [self updateIsConnectedLabels];
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

                [self authenticationCodeForManufacturingID:manufacturingID completion:^(NSData *authenticationCode)
                {
                    if (authenticationCode)
                    {
                        self.penManager.pen.manufacturingID = manufacturingID;
                        [self sendString:[NSString stringWithFormat:@"Set Manufacturing ID: \"%@\"",
                                          manufacturingID]];

                        self.penManager.pen.authenticationCode = authenticationCode;
                        [self sendString:[NSString stringWithFormat:@"Set Authentication Code: \"%@\"",
                                          authenticationCode]];
                    }
                    else
                    {
                        [self reportError:@"Failed to calculate Authentication Code. Manufacturing ID will not be set."];
                    }
                }];
            }
            else
            {
                [self reportError:@"Invalid ID length."];
            }
        }
        else if ([command isEqualToString:kGetIdCommand])
        {
            BOOL didIssueRead = NO;
            if (self.penManager.state == FTPenManagerStateConnected)
            {
                if ([self.penManager.pen readManufacturingIDAndAuthCode])
                {
                    didIssueRead = YES;
                }
            }

            if (!didIssueRead)
            {
                [self sendString:@"Not ready to read manufacturing ID"];
            }
        }
        else if ([command isEqualToString:kGetBatteryLevelCommand])
        {
            NSString *result = [NSString stringWithFormat:@"Battery level: %d%%",
                                (self.penManager.pen.batteryLevel ?
                                 self.penManager.pen.batteryLevel.integerValue :
                                 -1)];
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
    if (self.isPCConnected)
    {
        [self.rscManager write:&c length:sizeof(c)];
    }
}

- (void)sendString:(NSString *)string
{
    NSAssert([string canBeConvertedToEncoding:NSASCIIStringEncoding], @"String must be ASCII");

    if (self.isPCConnected)
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

#pragma mark - Authentication Code

// Pops an alert that allows the user to enter a password. Returns the result asynchronously.
- (void)queryForPassword:(void (^)(NSString *password))completion
{
    RIButtonItem *buttonItem = [RIButtonItem itemWithLabel:@"OK"];
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Enter Passcode"
                                                        message:nil
                                               cancelButtonItem:buttonItem
                                               otherButtonItems:nil];
    alertView.alertViewStyle = UIAlertViewStyleSecureTextInput;

    __weak UIAlertView *weakAlertView = alertView;
    buttonItem.action =
    ^{
        if (completion)
        {
            completion([weakAlertView textFieldAtIndex:0].text);
        }
    };

    [alertView show];

}

- (void)authenticationCodeForManufacturingID:(NSString *)manufacturingID
                                  completion:(void (^)(NSData *authenticationCode))completion
{
    if (manufacturingID.length == 0 ||
        ![manufacturingID canBeConvertedToEncoding:NSASCIIStringEncoding])
    {
        [[[UIAlertView alloc] initWithTitle:@"Invalid Manufacturing ID"
                                    message:@"The manufacturing ID must be comprised of 20 ASCII characters."
                                   delegate:nil
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil] show];
        if (completion)
        {
            completion(nil);
        }
        return;
    }

    NSString *certPath = [applicationDocumentsDirectory() stringByAppendingPathComponent:@"cert.p12"];
    NSData *PKCS12Data = [NSData dataWithContentsOfFile:certPath];
    if (!PKCS12Data)
    {
        [[[UIAlertView alloc] initWithTitle:@"Signing Identity Not Present"
                                    message:@"Please install the p12 file in the iTunes Document Directory to continue."
                                   delegate:nil
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil] show];
        if (completion)
        {
            completion(nil);
        }
        return;
    }

    void (^calculateAuthenticationCode)() = ^()
    {
        NSAssert(self.authenticationCodeSigningIdentity != NULL, @"signing identity non-null");
        NSAssert(self.authenticationCodeSigningPublicKey != NULL, @"signing public key non-null");

        NSData *dataToSign = [manufacturingID dataUsingEncoding:NSASCIIStringEncoding];
        NSData *signature = [dataToSign createSignatureWithIdentity:self.authenticationCodeSigningIdentity];

        // To create the authorization code from the digital signature we first take the
        // SHA512 digest of it, then truncate it to the most significant 20 bytes.
        NSData *authCode = [signature SHA512Digest];
        NSData *authCode20Bytes = [authCode subdataWithRange:NSMakeRange(0, 20)];

        // To sanity check, make sure that we can verify the signature.
        NSAssert([dataToSign verifySignature:signature
                                andPublicKey:self.authenticationCodeSigningPublicKey],
                 @"Can verify signature using public key");

        if (completion)
        {
            completion(authCode20Bytes);
        }
    };

    void (^loadSigningIdentityAndCalculateAuthCode)(NSString *password) = ^(NSString *password)
    {
        SecIdentityRef identity = NULL;
        SecTrustRef trust = NULL;
        if (![PKCS12Data PKCS12ExtractIdentity:&identity
                                      andTrust:&trust
                                  withPassword:password])
        {
            [[[UIAlertView alloc] initWithTitle:@"Could Not Access Signing Identity"
                                        message:@"Please verify the password and try again."
                                       delegate:nil
                              cancelButtonTitle:@"OK"
                              otherButtonTitles:nil] show];

            // If the stored password is no longer valid for this PKCS12 file, then clear it.
            [self.PKCS12PasswordKeychainItem resetKeychainItem];

            if (completion)
            {
                completion(nil);
            }
            return;
        }

        [self.PKCS12PasswordKeychainItem setObject:password
                                            forKey:(__bridge id)kSecValueData];

        self.authenticationCodeSigningIdentity = identity;
        self.authenticationCodeSigningPublicKey = SecTrustCopyPublicKey(trust);
        CFRelease(trust);

        calculateAuthenticationCode();
    };

    if (self.authenticationCodeSigningIdentity != NULL &&
        self.authenticationCodeSigningPublicKey != NULL)
    {
        calculateAuthenticationCode();
    }
    else
    {
        NSString *storedPassword = [self.PKCS12PasswordKeychainItem objectForKey:(__bridge id)kSecValueData];
        if (storedPassword.length > 0)
        {
            loadSigningIdentityAndCalculateAuthCode(storedPassword);
        }
        else
        {
            [self queryForPassword:^(NSString *password) {
                loadSigningIdentityAndCalculateAuthCode(password);
            }];
        }
    }

    return;
}

@end
