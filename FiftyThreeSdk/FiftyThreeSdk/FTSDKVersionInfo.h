//
//  FTSDKVersionInfo.h
//  FiftyThreeSdk
//
//  Created by Peter Sibley on 3/10/14.
//  Copyright (c) 2014 FiftyThree. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FTSDKVersionInfo : NSObject
@property (nonatomic,readonly) NSString *version;
@property (nonatomic,readonly) NSInteger majorVersion;
@property (nonatomic,readonly) NSInteger minorVersion;
@property (nonatomic,readonly) NSString *commit;
@property (nonatomic,readonly) NSString *timestamp;
@end
