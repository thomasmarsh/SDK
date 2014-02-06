//
//  UIDeviceHardware.h
//  Classification
//
//  Created by Akil Narayan on 2013/07/10.
//  Copyright (c) 2013 Peter Sibley. All rights reserved.
//
//
//  Used to determine version of device software is running on.
#pragma once

#import <Foundation/Foundation.h>

@interface UIDeviceHardware : NSObject

- (NSString *) platform;
- (NSString *) platformString;

@end
