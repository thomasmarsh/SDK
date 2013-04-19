//
//  NSFileHandle+readLine.h
//  FiftyThreeSdkTestApp
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSFileHandle (readLine)

- (NSData *)readLineWithDelimiter:(NSString *)theDelimier;

@end
