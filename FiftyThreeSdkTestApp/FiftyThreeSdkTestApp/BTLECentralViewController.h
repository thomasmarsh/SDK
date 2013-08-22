//
//  BTLECentralViewController.h
//  FiftyThreeSdkTestApp
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <UIKit/UIKit.h>

@interface BTLECentralViewController : UIViewController

@property (weak, nonatomic) IBOutlet UILabel *pairingStatusLabel;
@property (weak, nonatomic) IBOutlet UIButton *pairButton;
@property (weak, nonatomic) IBOutlet UIButton *testConnectButton;
@property (weak, nonatomic) IBOutlet UIButton *tipStateButton;
@property (weak, nonatomic) IBOutlet UIButton *eraserStateButton;

- (IBAction)pairButtonTouchDown:(id)sender;
- (IBAction)pairButtonTouchUpInside:(id)sender;
- (IBAction)pairButtonTouchUpOutside:(id)sender;
- (IBAction)testConnectButtonPressed:(id)sender;

@property (weak, nonatomic) IBOutlet UIButton *connectButton;
- (IBAction)connectButtonPressed:(id)sender;

@property (weak, nonatomic) IBOutlet UIButton *updateFirmwareButton;
- (IBAction)updateFirmwareButtonPressed:(id)sender;

@property (weak, nonatomic) IBOutlet UIButton *trialSeparationButton;
- (IBAction)trialSeparationButtonPressed:(id)sender;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *infoButton;
- (IBAction)infoButtonPressed:(id)sender;

@property (weak, nonatomic) IBOutlet UIButton *clearButton;
- (IBAction)clearButtonPressed:(id)sender;

@property (weak, nonatomic) IBOutlet UIButton *annotateButton;
- (IBAction)annotateButtonPressed:(id)sender;

@property (weak, nonatomic) IBOutlet UIButton *shareButton;
- (IBAction)shareButtonPressed:(id)sender;

@end