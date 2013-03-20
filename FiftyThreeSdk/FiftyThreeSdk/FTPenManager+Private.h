//
//  FTPenPrivate.h
//  FiftyThreeSdk
//
//  Created by Adam on 3/12/13.
//  Copyright (c) 2013 FiftyThree. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FTPenManager ()

- (bool)isPenFirmwareUpdatable:(FTPen *)pen;
- (void)updateFirmware:(NSString *)imagePath forPen:(FTPen *)pen;

@end
