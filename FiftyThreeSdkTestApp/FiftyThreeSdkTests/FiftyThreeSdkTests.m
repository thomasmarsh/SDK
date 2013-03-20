//
//  FiftyThreeTests.m
//  FiftyThreeTests
//
//  Created by Adam on 3/5/13.
//  Copyright (c) 2013 FiftyThree. All rights reserved.
//

#import "FiftyThreeSdkTests.h"
#import "FiftyThreeSdk/FTPenManager.h"

@interface FiftyThreeSdkTests () <FTPenManagerDelegate>
@property int actualConnects;
@property int actualDisconnects;
@end

@implementation FiftyThreeSdkTests

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

- (void)resetDefaults
{
    NSString *appDomain = [[NSBundle mainBundle] bundleIdentifier];
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:appDomain];
}

- (void)testConnect
{
    int expectedDisconnects = 0;
    int expectedConnects = 0;
    
    [self resetDefaults];
    
    FTPenManager *manager = [[FTPenManager alloc] initWithDelegate:self];
    while (!manager.isReady) {} // BUGBUG - should there be a callback on ready state change?
    
    STAssertNil(manager.pairedPen, @"start with no paired pen");
    STAssertNil(manager.connectedPen, @"start with no connected pen");
    
    [manager startPairing];
    
    [self waitForStatus:SenAsyncTestCaseStatusSucceeded timeout:10.0];
    STAssertEquals(++expectedConnects, self.actualConnects, nil);
    
    [manager disconnect];
    
    [self waitForStatus:SenAsyncTestCaseStatusSucceeded timeout:1.0];
    STAssertEquals(++expectedDisconnects, self.actualDisconnects, nil);
    
    [manager connect];
    
    [self waitForStatus:SenAsyncTestCaseStatusSucceeded timeout:1.0];
    STAssertEquals(++expectedConnects, self.actualConnects, nil);
    
    [manager disconnect];

    [self waitForStatus:SenAsyncTestCaseStatusSucceeded timeout:1.0];
    STAssertEquals(++expectedDisconnects, self.actualDisconnects, nil);
    
    // start again with paired pen
    
    manager = [[FTPenManager alloc] initWithDelegate:self];
    while (!manager.isReady) {}
    
    STAssertNotNil(manager.pairedPen, nil);
    STAssertFalse(manager.pairedPen.isConnected, nil);
    
    [manager connect];
    
    [self waitForStatus:SenAsyncTestCaseStatusSucceeded timeout:1.0];
    STAssertEquals(++expectedConnects, self.actualConnects, nil);
    
    STAssertTrue(manager.pairedPen.isConnected, nil);
    
    [manager deletePairedPen:manager.pairedPen];
    STAssertNil(manager.pairedPen, nil);
        
    [self waitForStatus:SenAsyncTestCaseStatusSucceeded timeout:1.0];
    STAssertEquals(++expectedDisconnects, self.actualDisconnects, nil);
    
    // start again with no paired pen
    
    manager = [[FTPenManager alloc] initWithDelegate:self];
    while (!manager.isReady) {}
    
    STAssertNil(manager.pairedPen, nil);
}


- (void)penManager:(FTPenManager *)penManager didPairWithPen:(FTPen *)pen
{
    STAssertEquals(pen, penManager.pairedPen, nil);
}

- (void)penManager:(FTPenManager *)penManager didConnectToPen:(FTPen *)pen
{
    self.actualConnects++;
    
    STAssertEquals(pen, penManager.connectedPen, nil);
    STAssertTrue(pen.isConnected, nil);
    STAssertEquals(penManager.pairedPen, penManager.connectedPen, nil);
    
    [self notify:SenAsyncTestCaseStatusSucceeded];
}

- (void)penManager:(FTPenManager *)penManager didFailConnectToPen:(FTPen *)pen
{
    [self notify:SenAsyncTestCaseStatusFailed];
}

- (void)penManager:(FTPenManager *)penManager didDisconnectFromPen:(FTPen *)pen
{
    self.actualDisconnects++;
    
    STAssertNil(penManager.connectedPen, nil);
    STAssertFalse(pen.isConnected, nil);
    
    [self notify:SenAsyncTestCaseStatusSucceeded];
}

- (void)penManager:(FTPenManager *)penManager didUpdateDeviceInfo:(FTPen *)pen
{
    
}

- (void)penManager:(FTPenManager *)penManager didUpdateDeviceBatteryLevel:(FTPen *)pen
{
    
}

@end
