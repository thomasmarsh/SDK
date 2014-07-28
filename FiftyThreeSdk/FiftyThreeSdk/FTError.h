//
//  FTError.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <Foundation/Foundation.h>

enum FTError
{
    FTErrorInvalid,
    FTErrorAborted
};

extern NSString * const kFiftyThreeErrorDomain;

enum
{
    // The pen connection process fails if, upon connecting, the pen's tip is not pressed. The user must keep
    // the pen pressed against the pairing spot until the connection is finished. If he/she releases early,
    // or the connection was established somehow without the tip being pressed, then the connection process
    // should be aborted.
    FTPenErrorConnectionFailedTipNotPressed
};
