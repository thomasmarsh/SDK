//
//  BTLEPeripheralViewController.h
//  charcoal-prototype
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BTLEPeripheralViewController : UIViewController
@property (weak, nonatomic) IBOutlet UISwitch *secureSwitch;
- (IBAction)secureSwitchChanged:(id)sender;

- (IBAction)tip1TouchUpInside:(id)sender;
- (IBAction)tip1TouchUpOutside:(id)sender;
- (IBAction)tip1TouchDown:(id)sender;

- (IBAction)tip2TouchUpInside:(id)sender;
- (IBAction)tip2TouchUpOutside:(id)sender;
- (IBAction)tip2TouchDown:(id)sender;
@property (weak, nonatomic) IBOutlet UILabel *connectionStatusLabel;
@end
