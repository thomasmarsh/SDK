//
//  ViewController.m
//  CharcoalLineTest
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "FiftyThreeSdk/FTPen+Private.h"
#import "FiftyThreeSdk/FTPenManager.h"
#import "RscMgr.h"
#import "ViewController.h"

@interface ViewController () <RscMgrDelegate, FTPenManagerDelegate, FTPenDelegate, FTPenPrivateDelegate>

@property (nonatomic) RscMgr *rscManager;
@property (nonatomic) FTPenManager *penManager;
@property (nonatomic) BOOL pairing;
@property (nonatomic) BOOL pcConnected;
@property (nonatomic) NSMutableString *commandBuffer;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.

    _rscManager = [[RscMgr alloc] init];
    [_rscManager setDelegate:self];

    _penManager = [[FTPenManager alloc] initWithDelegate:self];
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

- (void)penManager:(FTPenManager *)penManager didUpdateState:(FTPenManagerState)state
{
    if (state == FTPenManagerStateConnecting)
    {
        NSAssert(penManager.pen, @"pen is non-nil");
        penManager.pen.delegate = self;
        penManager.pen.privateDelegate = self;
    }

    [self updateDisplay];
}

- (void)penManager:(FTPenManager *)penManager didUpdateDeviceInfo:(FTPen *)pen
{
    [self displayPenInfo:pen];
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
    else if (self.penManager.state == FTPenManagerStateConnected)
    {
        [self.statusLabel setText:[NSString stringWithFormat:@"Connected to %@", self.penManager.pen.name]];
    }

    if (self.penManager.state == FTPenManagerStateConnected)
    {
        [self.connectButton setTitle:@"Disconnect" forState:UIControlStateNormal];
        self.penConnectedButton.highlighted = YES;
        self.connectButton.hidden = NO;
    }
    else
    {
        self.penConnectedButton.highlighted = NO;
        self.connectButton.hidden = YES;

        self.tip1State.highlighted = NO;
        self.tip2State.highlighted = NO;
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

#pragma mark -

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
        static const int kIdLength = 15;

        if ([command hasPrefix:kSetIdCommandPrefix])
        {
            if (command.length == kSetIdCommandPrefix.length + kIdLength)
            {
                NSString *manufacturingID = [command substringWithRange:NSMakeRange(command.length - kIdLength,
                                                                                    kIdLength)];

                if (self.penManager.state == FTPenManagerStateConnected)
                {
                    [self.penManager.pen setManufacturingID:manufacturingID];
                    [self sendString:[NSString stringWithFormat:@"Set Manufacturing ID: \"%@\"", manufacturingID]];
                }
                else
                {
                    [self reportError:@"Pen must be connected to set Manufacturing ID."];
                }
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
                [self.penManager.pen getManufacturingID];
            }
        }
        else
        {
            [self reportError:@"Unknown command."];
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
