//
//  FTAssert.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <Foundation/NSException.h>

#if defined(DEBUG) || defined(PREVIEW_BUILD) || defined(INTERNAL_BUILD)
    #ifndef USE_FT_ASSERT
        #define USE_FT_ASSERT TRUE
    #endif
#else
    #ifndef USE_FT_ASSERT
        #define USE_FT_ASSERT FALSE
        #define NSAssert(X,Y,...)
    #endif
#endif
