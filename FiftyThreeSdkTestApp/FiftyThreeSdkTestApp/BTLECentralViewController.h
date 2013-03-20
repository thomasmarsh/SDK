//
//  BTLECentralViewController.h
//  charcoal-prototype
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BTLECentralViewController : UIViewController

@property (weak, nonatomic) IBOutlet UILabel *pairingStatusLabel;
@property (weak, nonatomic) IBOutlet UIButton *pairButton;
@property (weak, nonatomic) IBOutlet UIButton *testConnectButton;
@property (weak, nonatomic) IBOutlet UIButton *tip1State;
@property (weak, nonatomic) IBOutlet UIButton *tip2State;

- (IBAction)pairButtonTouchDown:(id)sender;
- (IBAction)pairButtonTouchUpInside:(id)sender;
- (IBAction)pairButtonTouchUpOutside:(id)sender;
- (IBAction)testConnectButtonPressed:(id)sender;
@property (weak, nonatomic) IBOutlet UIButton *connectButton;
@property (weak, nonatomic) IBOutlet UIButton *disconnectButton;
- (IBAction)connectButtonPressed:(id)sender;
- (IBAction)disconnectButtonPressed:(id)sender;
@property (weak, nonatomic) IBOutlet UIButton *unpairButton;
- (IBAction)unpairButtonPressed:(id)sender;
@property (weak, nonatomic) IBOutlet UIButton *updateFirmwareButton;
- (IBAction)updateFirmwareButtonPressed:(id)sender;

@end
