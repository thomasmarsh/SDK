//
//  FiftyThreeSdkTests.m
//  FiftyThreeSdkTestApp
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "FiftyThreeSdk/FTPenManager.h"
#import "FiftyThreeSdkTests.h"

@interface FiftyThreeSdkTests ()
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
    [self waitForStatus:SenAsyncTestCaseStatusSucceeded timeout:10.0];

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
    [self waitForStatus:SenAsyncTestCaseStatusSucceeded timeout:10.0];

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
    [self waitForStatus:SenAsyncTestCaseStatusSucceeded timeout:10.0];

    STAssertNil(manager.pairedPen, nil);
}

- (void)penManagerDidUpdateState:(FTPenManager *)penManager
{
    STAssertEquals(penManager.state, FTPenManagerStateAvailable, nil);
    [self notify:SenAsyncTestCaseStatusSucceeded];
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

@end
