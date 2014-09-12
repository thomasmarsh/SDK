//
//  FTLogPrivate.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include "Core/Log.h"

DEFINE_LOG_MODULES(FTLogModule,
                   0x56878,
                   FTLogSDK,
                   FTLogSDKVerbose, // TODO: remove this in favor of using MLOG_DEBUG
                   FTLogSDKClassificationLinker)
