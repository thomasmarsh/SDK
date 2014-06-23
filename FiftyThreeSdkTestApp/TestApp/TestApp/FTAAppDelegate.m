//
//  FTAAppDelegate.m
//  TestApp
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#import "FTAAppDelegate.h"

@implementation FTAAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    return YES;
}

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation
{
    // See FTAViewControntroller updateFirmware:
    if ([[url absoluteString] hasSuffix:@"success"])
    {
        NSLog(@"Success url");
    }
    else if ([[url absoluteString] hasSuffix:@"error"])
    {
        NSLog(@"Error url");
    }
    else if ([[url absoluteString] hasSuffix:@"cancel"])
    {
        NSLog(@"Cancel url");
    }
    else
    {
        // Unknown.
        NSLog(@"Unexpected url");
    }
}

- (void)applicationWillResignActive:(UIApplication *)application
{
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
}

- (void)applicationWillTerminate:(UIApplication *)application
{
}

@end
