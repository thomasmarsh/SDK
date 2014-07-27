//
//  NSFileHandle+readLine.h
//  FiftyThreeSdkTestApp
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <Foundation/Foundation.h>

@interface NSFileHandle (readLine)

- (NSData *)readLineWithDelimiter:(NSString *)theDelimier;

@end
