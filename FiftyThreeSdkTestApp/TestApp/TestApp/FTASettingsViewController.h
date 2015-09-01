//
//  FTASettingsViewController.h
//  TestApp
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <FiftyThreeSdk/FiftyThreeSdk.h>
#import <UIKit/UIKit.h>

@protocol FTASettingsViewControllerDelegate<NSObject>

- (NSInteger)getFramerate;
- (void)setFramerate:(NSInteger)framerate;

@end

@interface FTASettingsViewController : UITableViewController
@property (nonatomic) FTPenInformation *info;
@property (nonatomic, weak) id<FTASettingsViewControllerDelegate> delegate;

- (id)initWithStyle:(UITableViewStyle)style :(id<FTASettingsViewControllerDelegate>)andDelegate;
@end
