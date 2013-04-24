//
//  FTPenServiceUUID.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#ifndef charcoal_prototype_FTPenService_h
#define charcoal_prototype_FTPenService_h

#define USE_FT_UUIDS 0

#define FT_PEN_TIP_STATE_PRESSED 1
#define FT_PEN_TIP_STATE_RELEASED 0

#if USE_FT_UUIDS

#define FT_PEN_SERVICE_UUID @"F774AC12-6B9F-4C30-A654-2EC44D974FE4"

#define FT_PEN_TIP1_STATE_UUID @"CA59A75A-B00B-422E-8D7D-7AEC163166BC"
#define FT_PEN_TIP2_STATE_UUID @"BAC99F09-C26D-4A99-899E-9FCBC06B665C"

#else  // Carbon-generated UUIDS

#define FT_PEN_SERVICE_UUID @"FFF0"

#define FT_PEN_TIP1_STATE_UUID @"FFF1"
#define FT_PEN_TIP2_STATE_UUID @"FFF2"

#endif

#endif
