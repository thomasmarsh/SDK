//
//  FTFirmwareUpdateProgressView.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <UIKit/UIKit.h>

@interface FTFirmwareUpdateProgressView : UIAlertView

@property (nonatomic) float percentComplete;

+ (FTFirmwareUpdateProgressView *)start;

- (void)dismiss;

@end
