//
//  FTPenServiceUUID.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#ifndef charcoal_prototype_FTPenService_h
#define charcoal_prototype_FTPenService_h

#define USE_FT_UUIDS 0
#define USE_TI_UUIDS 0

#define FT_PEN_TIP_STATE_PRESSED 1
#define FT_PEN_TIP_STATE_RELEASED 0

#if USE_FT_UUIDS

#define FT_PEN_SERVICE_UUID @"F774AC12-6B9F-4C30-A654-2EC44D974FE4"

#define FT_PEN_TIP1_STATE_UUID @"CA59A75A-B00B-422E-8D7D-7AEC163166BC"
#define FT_PEN_TIP2_STATE_UUID @"BAC99F09-C26D-4A99-899E-9FCBC06B665C"

#else

#if USE_TI_UUIDS // TI button service UUIDS

#define TI_SIMPLE_BLE_ADV_UUID @"FFF0"
#define FT_PEN_SERVICE_UUID @"FFE0" // Simple Keys Service

#define FT_PEN_TIP1_STATE_UUID @"FFE1" // Key Press State

#define TI_KEY_PRESS_STATE_NONE 0
#define TI_KEY_PRESS_STATE_KEY1 1
#define TI_KEY_PRESS_STATE_KEY2 2

#else  // Carbon-generated UUIDS

#define FT_PEN_SERVICE_UUID @"FFF0"

#define FT_PEN_TIP1_STATE_UUID @"FFF1"
#define FT_PEN_TIP2_STATE_UUID @"FFF2"

#endif

#endif // USE_TI_UUIDS

#endif
