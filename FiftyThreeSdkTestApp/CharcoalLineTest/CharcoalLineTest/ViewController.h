//
//  ViewController.h
//  CharcoalLineTest
//
//  Created by Adam on 5/9/13.
//  Copyright (c) 2013 FiftyThree. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController

@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (weak, nonatomic) IBOutlet UIButton *tip1State;
@property (weak, nonatomic) IBOutlet UIButton *tip2State;
@property (weak, nonatomic) IBOutlet UIButton *pairButton;
@property (weak, nonatomic) IBOutlet UIButton *pcConnectedButton;
@property (weak, nonatomic) IBOutlet UIButton *penConnectedButton;
@property (weak, nonatomic) IBOutlet UIButton *connectButton;

- (IBAction)pairButtonTouchUpInside:(id)sender;
- (IBAction)pairButtonTouchUpOutside:(id)sender;
- (IBAction)pairButtonTouchDown:(id)sender;
- (IBAction)infoButtonPressed:(id)sender;
- (IBAction)connectButtonPressed:(id)sender;

@end
