//
//  main.m
//  TestApp
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "FiftyThreeSdk/FTApplication.h"
#import "FTAAppDelegate.h"

int main(int argc, char * argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, NSStringFromClass([FTApplication class]), NSStringFromClass([FTAAppDelegate class]));
    }
}
