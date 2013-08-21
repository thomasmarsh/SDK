//
//  FTFirmwareUpdateProgressView.m
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "FTFirmwareUpdateProgressView.h"

NSString * const kUpdateProgressViewMessage = @"%.1f%% Complete\nTime Remaining: %02d:%02d";

@interface FTFirmwareUpdateProgressView ()

@property (nonatomic) NSDate *startTime;

@end

@implementation FTFirmwareUpdateProgressView

+ (FTFirmwareUpdateProgressView *)start;
{
    NSString *message = [NSString stringWithFormat:kUpdateProgressViewMessage, 0., 0, 0];
    FTFirmwareUpdateProgressView *view = [[FTFirmwareUpdateProgressView alloc] initWithTitle:@"Firmware Update"
                                                                                     message:message
                                                                                    delegate:nil
                                                                           cancelButtonTitle:@"Cancel"
                                                                           otherButtonTitles:nil, nil];
    view.startTime = [NSDate date];
    [view show];

    return view;
}

- (void)setPercentComplete:(float)percentComplete
{
    NSTimeInterval elapsed = -[self.startTime timeIntervalSinceNow];
    float totalTime = elapsed / (percentComplete / 100.0);
    float remainingTime = totalTime - (totalTime * percentComplete / 100.0);
    int minutes = (int)remainingTime / 60;
    int seconds = (int)remainingTime % 60;

    self.message = [NSString stringWithFormat:kUpdateProgressViewMessage, percentComplete, minutes, seconds];
    [self show];
}

- (void)dismiss
{
    [self dismissWithClickedButtonIndex:0 animated:NO];
}

@end
