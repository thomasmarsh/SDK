//
//  ViewController.h
//  CharcoalLineTest
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController

@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (weak, nonatomic) IBOutlet UIButton *pairButton;
@property (weak, nonatomic) IBOutlet UIButton *connectButton;
@property (weak, nonatomic) IBOutlet UIButton *updateFirmwareButton;
@property (weak, nonatomic) IBOutlet UIButton *updateStatsButton;
@property (weak, nonatomic) IBOutlet UILabel *deviceInfoLabel;
@property (weak, nonatomic) IBOutlet UILabel *connectionHistoryLabel;
@property (weak, nonatomic) IBOutlet UIButton *clearLastErrorButton;
@property (weak, nonatomic) IBOutlet UIButton *incrementInactivityTimeoutButton;
@property (weak, nonatomic) IBOutlet UIButton *decrementInactivityTimeoutButton;
@property (weak, nonatomic) IBOutlet UIButton *togglePressureButton;
@property (weak, nonatomic) IBOutlet UINavigationItem *appTitleNavItem;
@property (weak, nonatomic) IBOutlet UILabel *isTipPressedLabel;
@property (weak, nonatomic) IBOutlet UILabel *isEraserPressedLabel;
@property (weak, nonatomic) IBOutlet UILabel *isTouchPressedLabel;
@property (weak, nonatomic) IBOutlet UILabel *isPCConnectedLabel;
@property (weak, nonatomic) IBOutlet UILabel *isPenConnectedLabel;

- (IBAction)pairButtonTouchUpInside:(id)sender;
- (IBAction)pairButtonTouchUpOutside:(id)sender;
- (IBAction)pairButtonTouchDown:(id)sender;
- (IBAction)connectButtonPressed:(id)sender;
- (IBAction)updateFirmwareButtonTouchUpInside:(id)sender;
- (IBAction)clearLastErrorButtonTouchUpInside:(id)sender;
- (IBAction)updateStatsTouchUpInside:(id)sender;
- (IBAction)incrementInactivityTimeoutButtonTouchUpInside:(id)sender;
- (IBAction)decrementInactivityTimeoutButtonTouchUpInside:(id)sender;
- (IBAction)togglePressureButtonTouchUpInside:(id)sender;
- (IBAction)clearStatusButtonTouchUpInside:(id)sender;

@end
