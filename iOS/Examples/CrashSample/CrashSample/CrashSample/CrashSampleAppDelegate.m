//
//  CrashSampleAppDelegate.m
//  CrashSample
//
//  Created by jkaufman on 9/1/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "CrashSampleAppDelegate.h"
#import "CrashSampleViewController.h"
#import "AppBlade.h"

@implementation CrashSampleAppDelegate


@synthesize window=_window;

@synthesize viewController=_viewController;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
		// Populate with values from the project SDK settings
		// see README for details
    [[AppBlade sharedManager] setAppBladeProjectID:@"ca460dcb-b7c2-43c1-ba50-8b6cda63f369"];  //UUID
    [[AppBlade sharedManager] setAppBladeProjectToken:@"8f1792db8a39108c14fa8c89663eec98"]; //Token
    [[AppBlade sharedManager] setAppBladeProjectSecret:@"c8536a333fb292ba46fc98719c1cfdf6"]; //Secret
    [[AppBlade sharedManager] setAppBladeProjectIssuedTimestamp:@"1316609918"]; //Issued at
    
    [[AppBlade sharedManager] catchAndReportCrashes];

    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];
    [[AppBlade sharedManager] allowFeedbackReporting];

    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
     */
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    /*
     Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
     */
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    /*
     Called when the application is about to terminate.
     Save data if appropriate.
     See also applicationDidEnterBackground:.
     */
}

- (void)dealloc
{
    [_window release];
    [_viewController release];
    [super dealloc];
}

@end
