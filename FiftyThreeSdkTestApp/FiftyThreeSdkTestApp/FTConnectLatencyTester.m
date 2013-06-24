//
//  FTConnectLatencyTester.m
//  charcoal-prototype
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "FTConnectLatencyTester.h"
#import "FiftyThreeSdk/FTPenManager.h"

#include <mach/mach_time.h>
#include <inttypes.h>
#include <sys/time.h>

#define CONNECT_REPS 100

@interface FTConnectLatencyTester ()
{
    long _timeResults[CONNECT_REPS];
    void (^_complete)(NSError *error);
}

@property (nonatomic) FTPenManager* penManager;
@property int connectCount;
@property uint64_t startTime;

@end

@implementation FTConnectLatencyTester

- (id)initWithPenManager:(FTPenManager *)penManager
{
    self = [super init];
    if (self) {
        _penManager = penManager;
        _connectCount = CONNECT_REPS;
    }
    return self;
}

- (long)currentTimeMillis
{
    struct timeval time;
    gettimeofday(&time, NULL);
    long millis = (time.tv_sec * 1000) + (time.tv_usec / 1000);
    return millis;
}

- (void)penManagerDidUpdateState:(FTPenManager *)penManager;
{

}

- (void)penManager:(FTPenManager *)penManager didPairWithPen:(FTPen *)pen
{
}

- (void)penManager:(FTPenManager *)penManager didUnpairFromPen:(FTPen *)pen
{
}

- (void)penManager:(FTPenManager *)penManager didConnectToPen:(FTPen *)pen
{
    long elapsed = [self currentTimeMillis] - self.startTime;
    NSLog(@"elapsed time = %ld", elapsed);
    _timeResults[self.connectCount] = elapsed;

    if (self.connectCount == CONNECT_REPS - 1) {
        uint64_t sum = 0;
        uint64_t min = UINT64_MAX;
        uint64_t max = 0;
        for (int i = 0; i < CONNECT_REPS; i++) {
            uint64_t val = _timeResults[i];
            sum += val;
            if (val > max) max = val;
            if (val < min) min = val;
        }

        NSLog(@"Average connect time = %" PRIu64 " msec (min=%" PRIu64 " max=%" PRIu64 ")", (sum / CONNECT_REPS), min, max);

        _complete(nil);
    }

    [self.penManager disconnect];
}

- (void)penManager:(FTPenManager *)penManager didFailConnectToPen:(FTPen *)pen
{
}

- (void)penManager:(FTPenManager *)penManager didDisconnectFromPen:(FTPen *)pen
{
    self.connectCount++;
    [self doConnect];
}

- (void)penManager:(FTPenManager *)penManager didUpdateDeviceInfo:(FTPen *)pen
{

}

- (void)penManager:(FTPenManager *)penManager didUpdateDeviceBatteryLevel:(FTPen *)pen
{

}

- (void)startTest:(void(^)(NSError *error))complete;
{
    _complete = complete;
    self.connectCount = 0;

    [self doConnect];
}

- (void)doConnect
{
    NSLog(@"doConnect (count=%d)", _connectCount);

    if (self.connectCount < CONNECT_REPS)
    {
        self.startTime = [self currentTimeMillis];
        NSAssert(0, @"unimplemented");
//        [self.penManager connect];
    }
}

@end
