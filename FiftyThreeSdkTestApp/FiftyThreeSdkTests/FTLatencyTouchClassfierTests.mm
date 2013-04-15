//
//  FTLatencyTouchClassfierTests.m
//  FiftyThreeSdkTestApp
//
//  Created by Adam on 3/28/13.
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "FTLatencyTouchClassfierTests.h"
#import "NSFileHandle+readLine.h"

#include "Common/Touch.h"
#include "FiftyThreeSdk/PenEvent.h"

using namespace fiftythree::sdk;
using namespace fiftythree::common;
using std::string;

@implementation FTLatencyTouchClassfierTests

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
    
    _Classifier = LatencyTouchClassifier::New();
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

- (void)processStrokeDataFile:(NSString *)filename
{
    NSArray *pathComponents = [filename componentsSeparatedByString:@"."];
    NSString* path = [[NSBundle bundleForClass:[self class]] pathForResource:pathComponents[0] ofType:pathComponents[1]];
    NSFileHandle *file = [NSFileHandle fileHandleForReadingAtPath:path];
    NSData *data = nil;
    do {
        data = [file readLineWithDelimiter:@"\n"];
        NSString *stringData = [[NSString alloc] initWithBytes:[data bytes]
                                  length:[data length] encoding: NSUTF8StringEncoding];
        
        NSArray *components = [stringData componentsSeparatedByString:@"="];
        if ([components count] != 2)
        {
            continue;
            //STAssertTrue(false, @"invalid data");
        }
        
        NSString *prefix = components[0];
        NSString *eventData = components[1];
        eventData = [eventData stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        if ([prefix isEqualToString:@"touch"])
        {
            Touch::cPtr touch = Touch::FromString(std::string([eventData cStringUsingEncoding:NSUTF8StringEncoding]));
            
            TouchesSet touchesSet;
            touchesSet.insert(touch);
            _Classifier->TouchesBegan(touchesSet);
        }
        else if ([prefix isEqualToString:@"pen"])
        {
            PenEvent::Ptr penEvent = PenEvent::FromString(std::string([eventData cStringUsingEncoding:NSUTF8StringEncoding]));
            
            _Classifier->ProcessPenEvent(*penEvent);
        }
        else if ([prefix isEqualToString:@"strokestate"])
        {
            
        }
    } while (data);
}

- (void)testStrokeData
{
    [self processStrokeDataFile:@"strokedata-3.prd"];
}

@end
