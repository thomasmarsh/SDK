//
//  FTServiceUUIDs.m
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "FTServiceUUIDs.h"

#pragma mark - Pen Service

// 1DEF5645-3C5D-4667-973D-8965706A2961
#define FT_PEN_SERVICE_UUID CFUUIDGetConstantUUIDWithBytes(kCFAllocatorSystemDefault, 0x1D, 0xEF, 0x56, 0x45, 0x3C, 0x5D, 0x46, 0x67, 0x97, 0x3D, 0x89, 0x65, 0x70, 0x6A, 0x29, 0x61)

// 9E289D8F-3B25-4CE7-B8A8-B624BB3FC5C7
#define FT_PEN_SERVICE_IS_TIP_PRESSED_UUID CFUUIDGetConstantUUIDWithBytes(kCFAllocatorSystemDefault, 0x9E, 0x28, 0x9D, 0x8F, 0x3B, 0x25, 0x4C, 0xE7, 0xB8, 0xA8, 0xB6, 0x24, 0xBB, 0x3F, 0xC5, 0xC7)

// 4FB6FE50-39D9-4B12-A523-8DC8857542E6
#define FT_PEN_SERVICE_IS_ERASER_PRESSED_UUID CFUUIDGetConstantUUIDWithBytes(kCFAllocatorSystemDefault, 0x4F, 0xB6, 0xFE, 0x50, 0x39, 0xD9, 0x4B, 0x12, 0xA5, 0x23, 0x8D, 0xC8, 0x85, 0x75, 0x42, 0xE6)

// EB1B235C-84D8-4595-AD89-9A58187AF718
#define FT_PEN_SERVICE_TIP_PRESSURE_UUID CFUUIDGetConstantUUIDWithBytes(kCFAllocatorSystemDefault, 0xEB, 0x1B, 0x23, 0x5C, 0x84, 0xD8, 0x45, 0x95, 0xAD, 0x89, 0x9A, 0x58, 0x18, 0x7A, 0xF7, 0x18)

// A5A0087A-2140-410D-9B3C-23D93EF212E5
#define FT_PEN_SERVICE_ERASER_PRESSURE_UUID CFUUIDGetConstantUUIDWithBytes(kCFAllocatorSystemDefault, 0xA5, 0xA0, 0x08, 0x7A, 0x21, 0x40, 0x41, 0x0D, 0x9B, 0x3C, 0x23, 0xD9, 0x3E, 0xF2, 0x12, 0xE5)

// 1A59BBBD-8205-4699-9B07-F477A0510C67
#define FT_PEN_SERVICE_BATTERY_LEVEL_UUID CFUUIDGetConstantUUIDWithBytes(kCFAllocatorSystemDefault, 0x1A, 0x59, 0xBB, 0xBD, 0x82, 0x05, 0x46, 0x99, 0x9B, 0x07, 0xF4, 0x77, 0xA0, 0x51, 0x0C, 0x67)

// A314488F-266F-4A7B-AFEE-6034B2F59808
#define FT_PEN_SERVICE_HAS_LISTENER_UUID CFUUIDGetConstantUUIDWithBytes(kCFAllocatorSystemDefault, 0xA3, 0x14, 0x48, 0x8F, 0x26, 0x6F, 0x4A, 0x7B, 0xAF, 0xEE, 0x60, 0x34, 0xB2, 0xF5, 0x98, 0x08)

// 9B772BAB-97A0-4C1F-9644-1B4F9530AA35
#define FT_PEN_SERVICE_SHOULD_SWING_UUID CFUUIDGetConstantUUIDWithBytes(kCFAllocatorSystemDefault, 0x9B, 0x77, 0x2B, 0xAB, 0x97, 0xA0, 0x4C, 0x1F, 0x96, 0x44, 0x1B, 0x4F, 0x95, 0x30, 0xAA, 0x35)

// FC2FE4B4-BB68-4A9E-A999-373BAA29C809
#define FT_PEN_SERVICE_SHOULD_POWER_OFF_UUID CFUUIDGetConstantUUIDWithBytes(kCFAllocatorSystemDefault, 0xFC, 0x2F, 0xE4, 0xB4, 0xBB, 0x68, 0x4A, 0x9E, 0xA9, 0x99, 0x37, 0x3B, 0xAA, 0x29, 0xC8, 0x09)

// 80F47BEF-58EF-4C75-9F08-7453BA896DA5
#define FT_PEN_SERVICE_INACTIVITY_TIMEOUT_UUID CFUUIDGetConstantUUIDWithBytes(kCFAllocatorSystemDefault, 0x80, 0xF4, 0x7B, 0xEF, 0x58, 0xEF, 0x4C, 0x75, 0x9F, 0x08, 0x74, 0x53, 0xBA, 0x89, 0x6D, 0xA5)

// A9FE2C8F-9A5D-429A-A4B2-C5E63AF22FB3
#define FT_PEN_SERVICE_PRESSURE_SETUP_UUID CFUUIDGetConstantUUIDWithBytes(kCFAllocatorSystemDefault, 0xA9, 0xFE, 0x2C, 0x8F, 0x9A, 0x5D, 0x42, 0x9A, 0xA4, 0xB2, 0xC5, 0xE6, 0x3A, 0xF2, 0x2F, 0xB3)

// 0976668C-001F-4744-8335-0E147B697CAE
#define FT_PEN_SERVICE_MANUF_ID_STRING_UUID CFUUIDGetConstantUUIDWithBytes(kCFAllocatorSystemDefault, 0x09, 0x76, 0x66, 0x8C, 0x00, 0x1F, 0x47, 0x44, 0x83, 0x35, 0x0E, 0x14, 0x7B, 0x69, 0x7C, 0xAE)

// 5749A836-6E3A-4CA5-B8CA-225A4C635D8E
#define FT_PEN_SERVICE_LAST_ERROR_CODE_UUID CFUUIDGetConstantUUIDWithBytes(kCFAllocatorSystemDefault, 0x57, 0x49, 0xA8, 0x36, 0x6E, 0x3A, 0x4C, 0xA5, 0xB8, 0xCA, 0x22, 0x5A, 0x4C, 0x63, 0x5D, 0x8E)

// 6041750F-F284-4125-BFB4-E912878614D7
#define FT_PEN_SERVICE_AUTH_CODE_UUID CFUUIDGetConstantUUIDWithBytes(kCFAllocatorSystemDefault, 0x60, 0x41, 0x75, 0x0F, 0xF2, 0x84, 0x41, 0x25, 0xBF, 0xB4, 0xE9, 0x12, 0x87, 0x86, 0x14, 0xD7)

// 0365CFC0-BE72-11E3-A496-0002A5D5C51B
#define FT_PEN_SERVICE_CENTRAL_ID_UUID CFUUIDGetConstantUUIDWithBytes(kCFAllocatorSystemDefault, 0x03, 0x65, 0xCF, 0xC0, 0xBE, 0x72, 0x11, 0xE3, 0xA4, 0x96, 0x00, 0x02, 0xA5, 0xD5, 0xC5, 0x1B)

@implementation FTPenServiceUUIDs

+ (CBUUID *)penService
{
    return [CBUUID UUIDWithCFUUID:FT_PEN_SERVICE_UUID];
}

+ (CBUUID *)isTipPressed
{
    return [CBUUID UUIDWithCFUUID:FT_PEN_SERVICE_IS_TIP_PRESSED_UUID];
}

+ (CBUUID *)isEraserPressed
{
    return [CBUUID UUIDWithCFUUID:FT_PEN_SERVICE_IS_ERASER_PRESSED_UUID];
}

+ (CBUUID *)tipPressure
{
    return [CBUUID UUIDWithCFUUID:FT_PEN_SERVICE_TIP_PRESSURE_UUID];
}

+ (CBUUID *)eraserPressure
{
    return [CBUUID UUIDWithCFUUID:FT_PEN_SERVICE_ERASER_PRESSURE_UUID];
}

+ (CBUUID *)batteryLevel
{
    return [CBUUID UUIDWithCFUUID:FT_PEN_SERVICE_BATTERY_LEVEL_UUID];
}

+ (CBUUID *)hasListener
{
    return [CBUUID UUIDWithCFUUID:FT_PEN_SERVICE_HAS_LISTENER_UUID];
}

+ (CBUUID *)shouldSwing
{
    return [CBUUID UUIDWithCFUUID:FT_PEN_SERVICE_SHOULD_SWING_UUID];
}

+ (CBUUID *)shouldPowerOff
{
    return [CBUUID UUIDWithCFUUID:FT_PEN_SERVICE_SHOULD_POWER_OFF_UUID];
}

+ (CBUUID *)inactivityTimeout
{
    return [CBUUID UUIDWithCFUUID:FT_PEN_SERVICE_INACTIVITY_TIMEOUT_UUID];
}

+ (CBUUID *)pressureSetup
{
    return [CBUUID UUIDWithCFUUID:FT_PEN_SERVICE_PRESSURE_SETUP_UUID];
}

+ (CBUUID *)manufacturingID
{
    return [CBUUID UUIDWithCFUUID:FT_PEN_SERVICE_MANUF_ID_STRING_UUID];
}

+ (CBUUID *)lastErrorCode
{
    return [CBUUID UUIDWithCFUUID:FT_PEN_SERVICE_LAST_ERROR_CODE_UUID];
}

+ (CBUUID *)authenticationCode
{
    return [CBUUID UUIDWithCFUUID:FT_PEN_SERVICE_AUTH_CODE_UUID];
}

+ (CBUUID *)centralId
{
    return [CBUUID UUIDWithCFUUID:FT_PEN_SERVICE_CENTRAL_ID_UUID];
}

+ (NSString *)nameForUUID:(CBUUID *)UUID
{
    NSDictionary *UUIDs = @{ [FTPenServiceUUIDs penService] : @"PenService",
                             [FTPenServiceUUIDs isTipPressed] : @"IsTipPressed",
                             [FTPenServiceUUIDs isEraserPressed] : @"IsEraserPressed",
                             [FTPenServiceUUIDs tipPressure] : @"TipPressure",
                             [FTPenServiceUUIDs eraserPressure] : @"EraserPressure",
                             [FTPenServiceUUIDs batteryLevel] : @"BatteryLevel",
                             [FTPenServiceUUIDs hasListener] : @"HasListener",
                             [FTPenServiceUUIDs shouldSwing] : @"ShouldSwing",
                             [FTPenServiceUUIDs shouldPowerOff] : @"ShouldPowerOff",
                             [FTPenServiceUUIDs inactivityTimeout] : @"InactivityTimeout",
                             [FTPenServiceUUIDs pressureSetup] : @"PressureSetup",
                             [FTPenServiceUUIDs manufacturingID] : @"ManufacturingID",
                             [FTPenServiceUUIDs lastErrorCode] : @"LastErrorCode",
                             [FTPenServiceUUIDs authenticationCode] : @"AuthenticationCode",
                             [FTPenServiceUUIDs centralId] : @"CentralId",
                             };
    return [UUIDs objectForKey:UUID];
}

@end

#pragma mark - Pen Usage Service

// 55518435-9BAB-4612-BDCE-F5B0C8C127AC
#define FT_PEN_USAGE_SERVICE_UUID CFUUIDGetConstantUUIDWithBytes(kCFAllocatorSystemDefault, 0x55, 0x51, 0x84, 0x35, 0x9B, 0xAB, 0x46, 0x12, 0xBD, 0xCE, 0xF5, 0xB0, 0xC8, 0xC1, 0x27, 0xAC)

// 6D5E0BA1-D6EB-4958-B4B8-75DA9BAC47BE
#define FT_PEN_USAGE_SERVICE_NUM_TIP_PRESSES_UUID CFUUIDGetConstantUUIDWithBytes(kCFAllocatorSystemDefault, 0x6D, 0x5E, 0x0B, 0xA1, 0xD6, 0xEB, 0x49, 0x58, 0xB4, 0xB8, 0x75, 0xDA, 0x9B, 0xAC, 0x47, 0xBE)

// 604B133E-4B22-4815-A484-365DE9D2A790
#define FT_PEN_USAGE_SERVICE_NUM_ERASER_PRESSES_UUID CFUUIDGetConstantUUIDWithBytes(kCFAllocatorSystemDefault, 0x60, 0x4B, 0x13, 0x3E, 0x4B, 0x22, 0x48, 0x15, 0xA4, 0x84, 0x36, 0x5D, 0xE9, 0xD2, 0xA7, 0x90)

// 2B9066F7-6C2C-43C0-9B93-1B6EB9B11A01
#define FT_PEN_USAGE_SERVICE_NUM_FAILED_CONN_UUID CFUUIDGetConstantUUIDWithBytes(kCFAllocatorSystemDefault, 0x2B, 0x90, 0x66, 0xF7, 0x6C, 0x2C, 0x43, 0xC0, 0x9B, 0x93, 0x1B, 0x6E, 0xB9, 0xB1, 0x1A, 0x01)

// 3C797361-7DA5-48F2-AAD9-6580BF165526
#define FT_PEN_USAGE_SERVICE_NUM_SUCCESSFUL_CONN_UUID CFUUIDGetConstantUUIDWithBytes(kCFAllocatorSystemDefault, 0x3C, 0x79, 0x73, 0x61, 0x7D, 0xA5, 0x48, 0xF2, 0xAA, 0xD9, 0x65, 0x80, 0xBF, 0x16, 0x55, 0x26)

// D78385CF-DA8A-41D0-9F6B-6C0013B6C094
#define FT_PEN_USAGE_SERVICE_NUM_RESETS_UUID CFUUIDGetConstantUUIDWithBytes(kCFAllocatorSystemDefault, 0xD7, 0x83, 0x85, 0xCF, 0xDA, 0x8A, 0x41, 0xD0, 0x9F, 0x6B, 0x6C, 0x00, 0x13, 0xB6, 0xC0, 0x94)

// 703DA5B0-A1E1-45B4-882A-0AE22249D46F
#define FT_PEN_USAGE_SERVICE_NUM_LINK_TERM_UUID CFUUIDGetConstantUUIDWithBytes(kCFAllocatorSystemDefault, 0x70, 0x3D, 0xA5, 0xB0, 0xA1, 0xE1, 0x45, 0xB4, 0x88, 0x2A, 0x0A, 0xE2, 0x22, 0x49, 0xD4, 0x6F)

// 2724E73A-F4F2-407C-84F6-DF6B9AA6C640
#define FT_PEN_USAGE_SERVICE_NUM_DROPPED_NOTIF_UUID CFUUIDGetConstantUUIDWithBytes(kCFAllocatorSystemDefault, 0x27, 0x24, 0xE7, 0x3A, 0xF4, 0xF2, 0x40, 0x7C, 0x84, 0xF6, 0xDF, 0x6B, 0x9A, 0xA6, 0xC6, 0x40)

// 442BBE12-C44D-4332-AFDC-138DDAAD3E44
#define FT_PEN_USAGE_SERVICE_CONNECTED_SECONDS_UUID CFUUIDGetConstantUUIDWithBytes(kCFAllocatorSystemDefault, 0x44, 0x2B, 0xBE, 0x12, 0xC4, 0x4D, 0x43, 0x32, 0xAF, 0xDC, 0x13, 0x8D, 0xDA, 0xAD, 0x3E, 0x44)

@implementation FTPenUsageServiceUUIDs

+ (CBUUID *)penUsageService
{
    return [CBUUID UUIDWithCFUUID:FT_PEN_USAGE_SERVICE_UUID];
}

+ (CBUUID *)numTipPresses
{
    return [CBUUID UUIDWithCFUUID:FT_PEN_USAGE_SERVICE_NUM_TIP_PRESSES_UUID];
}

+ (CBUUID *)numEraserPresses
{
    return [CBUUID UUIDWithCFUUID:FT_PEN_USAGE_SERVICE_NUM_ERASER_PRESSES_UUID];
}

+ (CBUUID *)numFailedConnections
{
    return [CBUUID UUIDWithCFUUID:FT_PEN_USAGE_SERVICE_NUM_FAILED_CONN_UUID];
}

+ (CBUUID *)numSuccessfulConnections
{
    return [CBUUID UUIDWithCFUUID:FT_PEN_USAGE_SERVICE_NUM_SUCCESSFUL_CONN_UUID];
}

+ (CBUUID *)numResets
{
    return [CBUUID UUIDWithCFUUID:FT_PEN_USAGE_SERVICE_NUM_RESETS_UUID];
}

+ (CBUUID *)numLinkTerminations
{
    return [CBUUID UUIDWithCFUUID:FT_PEN_USAGE_SERVICE_NUM_LINK_TERM_UUID];
}

+ (CBUUID *)numDroppedNotifications
{
    return [CBUUID UUIDWithCFUUID:FT_PEN_USAGE_SERVICE_NUM_DROPPED_NOTIF_UUID];
}

+ (CBUUID *)connectedSeconds
{
    return [CBUUID UUIDWithCFUUID:FT_PEN_USAGE_SERVICE_CONNECTED_SECONDS_UUID];
}

+ (NSString *)nameForUUID:(CBUUID *)UUID
{
    NSDictionary *UUIDs = @{ [FTPenUsageServiceUUIDs penUsageService] : @"PenUsageService",
                             [FTPenUsageServiceUUIDs numTipPresses] : @"NumTipPresses",
                             [FTPenUsageServiceUUIDs numEraserPresses] : @"NumEraserPresses",
                             [FTPenUsageServiceUUIDs numFailedConnections] : @"NumFailedConnections",
                             [FTPenUsageServiceUUIDs numSuccessfulConnections] : @"NumSuccesfulConnections",
                             [FTPenUsageServiceUUIDs numResets] : @"NumResets",
                             [FTPenUsageServiceUUIDs numLinkTerminations] : @"NumLinkTerminations",
                             [FTPenUsageServiceUUIDs numDroppedNotifications] : @"NumDroppedNotifications",
                             [FTPenUsageServiceUUIDs connectedSeconds] : @"ConnectedSeconds",
                             };

    return [UUIDs objectForKey:UUID];
}

@end

#pragma mark - Device Info Service

@implementation FTDeviceInfoServiceUUIDs

+ (CBUUID *)deviceInfoService
{
    return [CBUUID UUIDWithString:@"0x180A"];
}

+ (CBUUID *)manufacturerName
{
    return [CBUUID UUIDWithString:@"0x2A29"];
}

+ (CBUUID *)modelNumber
{
    return [CBUUID UUIDWithString:@"0x2A24"];
}

+ (CBUUID *)serialNumber
{
    return [CBUUID UUIDWithString:@"0x2A25"];
}

+ (CBUUID *)firmwareRevision
{
    return [CBUUID UUIDWithString:@"0x2A26"];
}

+ (CBUUID *)hardwareRevision
{
    return [CBUUID UUIDWithString:@"0x2A27"];
}

+ (CBUUID *)softwareRevision
{
    return [CBUUID UUIDWithString:@"0x2A28"];
}

+ (CBUUID *)systemID
{
    return [CBUUID UUIDWithString:@"0x2A23"];
}

+ (CBUUID *)IEEECertificationData
{
    return [CBUUID UUIDWithString:@"0x2A2A"];
}

+ (CBUUID *)PnPID
{
    return [CBUUID UUIDWithString:@"0x2A50"];
}

+ (NSString *)nameForUUID:(CBUUID *)UUID
{
    NSDictionary *UUIDs = @{ [FTDeviceInfoServiceUUIDs deviceInfoService] : @"DeviceInfoService",
                             [FTDeviceInfoServiceUUIDs manufacturerName] : @"ManufacturerName",
                             [FTDeviceInfoServiceUUIDs modelNumber] : @"ModelNumber",
                             [FTDeviceInfoServiceUUIDs serialNumber] : @"SerialNumber",
                             [FTDeviceInfoServiceUUIDs firmwareRevision] : @"FirmwareRevision",
                             [FTDeviceInfoServiceUUIDs hardwareRevision] : @"HardwareRevision",
                             [FTDeviceInfoServiceUUIDs softwareRevision] : @"SoftwareRevision",
                             [FTDeviceInfoServiceUUIDs systemID] : @"SystemID",
                             [FTDeviceInfoServiceUUIDs IEEECertificationData] : @"IEEECertificationData",
                             [FTDeviceInfoServiceUUIDs PnPID] : @"PnPId"};

    return [UUIDs objectForKey:UUID];
}

@end

#pragma mark -

NSString *FTNameForServiceUUID(CBUUID *UUID)
{
    NSString *name = [FTPenServiceUUIDs nameForUUID:UUID];
    if (!name)
    {
        name = [FTPenUsageServiceUUIDs nameForUUID:UUID];
    }
    if (!name)
    {
        name = [FTDeviceInfoServiceUUIDs nameForUUID:UUID];
    }

    return name;
}
