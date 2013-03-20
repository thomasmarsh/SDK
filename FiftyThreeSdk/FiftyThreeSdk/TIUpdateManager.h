//
//  TIUpdateManager.h
//  charcoal-prototype
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CBPeripheral;

@interface TIUpdateManager : NSObject
- (id) init __unavailable;
- (id)initWithPeripheral:(CBPeripheral *)peripheral;
- (void)updateImage:(NSString *)filePath complete:(void(^)(TIUpdateManager *client, NSError *error))complete;
@end
