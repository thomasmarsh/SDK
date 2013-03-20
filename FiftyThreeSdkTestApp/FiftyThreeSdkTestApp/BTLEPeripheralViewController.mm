//
//  BTLEPeripheralViewController.mm
//  charcoal-prototype
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "BTLEPeripheralViewController.h"
#import "TiUpdateService.h"
#import "FTPenService.h"

@interface BTLEPeripheralViewController () <FTPenServiceDelegate>

@property (strong, nonatomic) TiUpdateService *updateService;
@property (strong, nonatomic) FTPenService* penService;

@end

@implementation BTLEPeripheralViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)viewWillAppear:(BOOL)animated
{
    _updateService = [[TiUpdateService alloc] init];
    _penService = [[FTPenService alloc] init];
    _penService.delegate = self;
}

- (void)viewWillDisappear:(BOOL)animated
{
    _updateService = nil;
    _penService = nil;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)penService:(FTPenService *)penService connectionStateChanged:(BOOL)connected
{
    if (connected) {
        [self.connectionStatusLabel setText:@"Connected"];
    } else {
        [self.connectionStatusLabel setText:@"Disconnected"];
    }
}

- (IBAction)secureSwitchChanged:(id)sender {
    self.penService.secure = self.secureSwitch.on;
}

- (IBAction)tip1TouchUpInside:(id)sender
{
    self.penService.tip1Pressed = NO;
}

- (IBAction)tip1TouchUpOutside:(id)sender
{
    self.penService.tip1Pressed = NO;
}

- (IBAction)tip1TouchDown:(id)sender
{
    self.penService.tip1Pressed = YES;
}

- (IBAction)tip2TouchUpInside:(id)sender
{
    self.penService.tip2Pressed = NO;
}

- (IBAction)tip2TouchUpOutside:(id)sender
{
    self.penService.tip2Pressed = NO;
}

- (IBAction)tip2TouchDown:(id)sender
{
    self.penService.tip2Pressed = YES;
}

@end
