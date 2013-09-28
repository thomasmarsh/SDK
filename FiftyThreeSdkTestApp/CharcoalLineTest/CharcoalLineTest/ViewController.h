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
@property (weak, nonatomic) IBOutlet UIButton *tipStateButton;
@property (weak, nonatomic) IBOutlet UIButton *eraserStateButton;
@property (weak, nonatomic) IBOutlet UIButton *pairButton;
@property (weak, nonatomic) IBOutlet UIButton *pcConnectedButton;
@property (weak, nonatomic) IBOutlet UIButton *penConnectedButton;
@property (weak, nonatomic) IBOutlet UIButton *connectButton;
@property (weak, nonatomic) IBOutlet UIButton *updateFirmwareButton;
@property (weak, nonatomic) IBOutlet UIButton *updateStatsButton;
@property (weak, nonatomic) IBOutlet UIButton *touchButton;
@property (weak, nonatomic) IBOutlet UILabel *deviceInfoLabel;
@property (weak, nonatomic) IBOutlet UILabel *connectionHistoryLabel;
@property (weak, nonatomic) IBOutlet UIButton *clearLastErrorButton;
@property (weak, nonatomic) IBOutlet UINavigationItem *appTitleNavItem;

- (IBAction)pairButtonTouchUpInside:(id)sender;
- (IBAction)pairButtonTouchUpOutside:(id)sender;
- (IBAction)pairButtonTouchDown:(id)sender;
- (IBAction)connectButtonPressed:(id)sender;
- (IBAction)updateFirmwareButtonTouchUpInside:(id)sender;
- (IBAction)clearLastErrorButtonTouchUpInside:(id)sender;
- (IBAction)updateStatsTouchUpInside:(id)sender;

@end
