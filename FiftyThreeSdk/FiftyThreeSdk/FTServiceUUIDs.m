//
//  FTServiceUUIDs.m
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "FTServiceUUIDs.h"

#pragma mark - PenService

// 1DEF5645-3C5D-4667-973D-8965706A2961
#define FT_PEN_SERVICE_UUID CFUUIDGetConstantUUIDWithBytes(kCFAllocatorSystemDefault, 0x1D, 0xEF, 0x56, 0x45, 0x3C, 0x5D, 0x46, 0x67, 0x97, 0x3D, 0x89, 0x65, 0x70, 0x6A, 0x29, 0x61)

// 9E289D8F-3B25-4CE7-B8A8-B624BB3FC5C7
#define FT_PEN_SERVICE_IS_TIP_PRESSED_UUID CFUUIDGetConstantUUIDWithBytes(kCFAllocatorSystemDefault, 0x9E, 0x28, 0x9D, 0x8F, 0x3B, 0x25, 0x4C, 0xE7, 0xB8, 0xA8, 0xB6, 0x24, 0xBB, 0x3F, 0xC5, 0xC7)

// 4FB6FE50-39D9-4B12-A523-8DC8857542E6
#define FT_PEN_SERVICE_IS_ERASER_PRESSED_UUID CFUUIDGetConstantUUIDWithBytes(kCFAllocatorSystemDefault, 0x4F, 0xB6, 0xFE, 0x50, 0x39, 0xD9, 0x4B, 0x12, 0xA5, 0x23, 0x8D, 0xC8, 0x85, 0x75, 0x42, 0xE6)

// 9B772BAB-97A0-4C1F-9644-1B4F9530AA35
#define FT_PEN_SERVICE_SHOULD_SWING_UUID CFUUIDGetConstantUUIDWithBytes(kCFAllocatorSystemDefault, 0x9B, 0x77, 0x2B, 0xAB, 0x97, 0xA0, 0x4C, 0x1F, 0x96, 0x44, 0x1B, 0x4F, 0x95, 0x30, 0xAA, 0x35)

// FC2FE4B4-BB68-4A9E-A999-373BAA29C809
#define FT_PEN_SERVICE_SHOULD_POWER_OFF_UUID CFUUIDGetConstantUUIDWithBytes(kCFAllocatorSystemDefault, 0xFC, 0x2F, 0xE4, 0xB4, 0xBB, 0x68, 0x4A, 0x9E, 0xA9, 0x99, 0x37, 0x3B, 0xAA, 0x29, 0xC8, 0x09)

// 34B8CD0F-D0A8-4589-8602-FB3EE4F5030C
#define FT_PEN_SERVICE_BATTERY_VOLTAGE_UUID CFUUIDGetConstantUUIDWithBytes(kCFAllocatorSystemDefault, 0x34, 0xB8, 0xCD, 0x0F, 0xD0, 0xA8, 0x45, 0x89, 0x86, 0x02, 0xFB, 0x3E, 0xE4, 0xF5, 0x03, 0x0C)

// 80F47BEF-58EF-4C75-9F08-7453BA896DA5
#define FT_PEN_SERVICE_INACTIVITY_TIME_UUID CFUUIDGetConstantUUIDWithBytes(kCFAllocatorSystemDefault, 0x80, 0xF4, 0x7B, 0xEF, 0x58, 0xEF, 0x4C, 0x75, 0x9F, 0x08, 0x74, 0x53, 0xBA, 0x89, 0x6D, 0xA5)

@implementation FTPenServiceUUIDs

+ (CBUUID *)penService
{
//    return [CBUUID UUIDWithCFUUID:FT_PEN_SERVICE_UUID];
    return [CBUUID UUIDWithString:@"FFF0"];
}

+ (CBUUID *)isTipPressed
{
//    return [CBUUID UUIDWithCFUUID:FT_PEN_SERVICE_IS_TIP_PRESSED_UUID];
    return [CBUUID UUIDWithString:@"FFF1"];
}

+ (CBUUID *)isEraserPressed
{
//    return [CBUUID UUIDWithCFUUID:FT_PEN_SERVICE_IS_ERASER_PRESSED_UUID];
    return [CBUUID UUIDWithString:@"FFF2"];
}

+ (CBUUID *)shouldSwing
{
    return [CBUUID UUIDWithCFUUID:FT_PEN_SERVICE_SHOULD_SWING_UUID];
}

+ (CBUUID *)shouldPowerOff
{
    return [CBUUID UUIDWithCFUUID:FT_PEN_SERVICE_SHOULD_POWER_OFF_UUID];
}

+ (CBUUID *)batteryVoltage
{
    return [CBUUID UUIDWithCFUUID:FT_PEN_SERVICE_BATTERY_VOLTAGE_UUID];
}

+ (CBUUID *)inactivityTime
{
    return [CBUUID UUIDWithCFUUID:FT_PEN_SERVICE_INACTIVITY_TIME_UUID];
}

+ (NSString *)nameForPenServiceUUID:(CBUUID *)UUID
{
    NSDictionary *UUIDs = @{ [FTPenServiceUUIDs penService] : @"PenService",
                             [FTPenServiceUUIDs isTipPressed] : @"IsTipPressed",
                             [FTPenServiceUUIDs isEraserPressed] : @"IsEraserPressed",
                             [FTPenServiceUUIDs shouldSwing] : @"ShouldSwing",
                             [FTPenServiceUUIDs shouldPowerOff] : @"ShouldPowerOff",
                             [FTPenServiceUUIDs batteryVoltage] : @"BatteryVoltage",
                             [FTPenServiceUUIDs inactivityTime] : @"InactivityTime"
                             };
    return [UUIDs objectForKey:UUID];
}

@end

#pragma mark - Pen Debug Service

//
// Pen Debug Service
//

// 55518435-9BAB-4612-BDCE-F5B0C8C127AC
#define FT_PEN_DEBUG_SERVICE_UUID CFUUIDGetConstantUUIDWithBytes(kCFAllocatorSystemDefault, 0x55, 0x51, 0x84, 0x35, 0x9B, 0xAB, 0x46, 0x12, 0xBD, 0xCE, 0xF5, 0xB0, 0xC8, 0xC1, 0x27, 0xAC)

// B0825032-5897-4BC9-8DF5-4DFC59705197
#define FT_PEN_DEBUG_SERVICE_DEVICE_STATE_UUID CFUUIDGetConstantUUIDWithBytes(kCFAllocatorSystemDefault, 0xB0, 0x82, 0x50, 0x32, 0x58, 0x97, 0x4B, 0xC9, 0x8D, 0xF5, 0x4D, 0xFC, 0x59, 0x70, 0x51, 0x97)

// EB1B235C-84D8-4595-AD89-9A58187AF718
#define FT_PEN_DEBUG_SERVICE_TIP_PRESSURE_UUID CFUUIDGetConstantUUIDWithBytes(kCFAllocatorSystemDefault, 0xEB, 0x1B, 0x23, 0x5C, 0x84, 0xD8, 0x45, 0x95, 0xAD, 0x89, 0x9A, 0x58, 0x18, 0x7A, 0xF7, 0x18)

// A5A0087A-2140-410D-9B3C-23D93EF212E5
#define FT_PEN_DEBUG_SERVICE_ERASER_PRESSURE_UUID CFUUIDGetConstantUUIDWithBytes(kCFAllocatorSystemDefault, 0xA5, 0xA0, 0x08, 0x7A, 0x21, 0x40, 0x41, 0x0D, 0x9B, 0x3C, 0x23, 0xD9, 0x3E, 0xF2, 0x12, 0xE5)

// E5407310-84CA-48CA-B3CC-F47AC1271C22
#define FT_PEN_DEBUG_SERVICE_LONG_PRESS_TIME_UUID CFUUIDGetConstantUUIDWithBytes(kCFAllocatorSystemDefault, 0xE5, 0x40, 0x73, 0x10, 0x84, 0xCA, 0x48, 0xCA, 0xB3, 0xCC, 0xF4, 0x7A, 0xC1, 0x27, 0x1C, 0x22)

// 31F51EB8-050D-4E4D-A549-397459259B77
#define FT_PEN_DEBUG_SERVICE_CONNECTION_TIME_UUID CFUUIDGetConstantUUIDWithBytes(kCFAllocatorSystemDefault, 0x31, 0xF5, 0x1E, 0xB8, 0x05, 0x0D, 0x4E, 0x4D, 0xA5, 0x49, 0x39, 0x74, 0x59, 0x25, 0x9B, 0x77)

@implementation FTPenDebugServiceUUIDs

+ (CBUUID *)penDebugService
{
    return [CBUUID UUIDWithCFUUID:FT_PEN_DEBUG_SERVICE_UUID];
}

+ (CBUUID *)deviceState
{
    return [CBUUID UUIDWithCFUUID:FT_PEN_DEBUG_SERVICE_DEVICE_STATE_UUID];
}

+ (CBUUID *)tipPressure
{
    return [CBUUID UUIDWithCFUUID:FT_PEN_DEBUG_SERVICE_TIP_PRESSURE_UUID];
}

+ (CBUUID *)erasurePressure
{
    return [CBUUID UUIDWithCFUUID:FT_PEN_DEBUG_SERVICE_ERASER_PRESSURE_UUID];
}

+ (CBUUID *)longPressTime
{
    return [CBUUID UUIDWithCFUUID:FT_PEN_DEBUG_SERVICE_LONG_PRESS_TIME_UUID];
}

+ (CBUUID *)connectionTime
{
    return [CBUUID UUIDWithCFUUID:FT_PEN_DEBUG_SERVICE_CONNECTION_TIME_UUID];
}

+ (NSString *)nameForPenDebugServiceUUID:(CBUUID *)UUID
{
    NSDictionary *UUIDs = @{ [FTPenDebugServiceUUIDs penDebugService] : @"PenDebugService",
                             [FTPenDebugServiceUUIDs deviceState] : @"DeviceState",
                             [FTPenDebugServiceUUIDs tipPressure] : @"TipPressure",
                             [FTPenDebugServiceUUIDs erasurePressure] : @"ErasurePressure",
                             [FTPenDebugServiceUUIDs longPressTime] : @"LongPressTime",
                             [FTPenDebugServiceUUIDs connectionTime] : @"ConnectionTime"
                             };

    return [UUIDs objectForKey:UUID];
}

@end

NSString *FTNameForServiceUUID(CBUUID *UUID)
{
    NSString *name = [FTPenServiceUUIDs nameForPenServiceUUID:UUID];
    if (!name)
    {
        name = [FTPenDebugServiceUUIDs nameForPenDebugServiceUUID:UUID];
    }

    return name;
}