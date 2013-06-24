//
//  FTPen.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, FTPenTip) {
    FTPenTip1,
    FTPenTip2
};

@protocol FTPenDelegate;
@class UIView;

@interface FTPen : NSObject
{
}

typedef struct
{
    uint8_t vendorIdSource;
    uint16_t vendorId;
    uint16_t productId;
    uint16_t productVersion;
} PnPID;

@property (nonatomic, readonly) BOOL isReady;

@property (nonatomic, weak) id<FTPenDelegate> delegate;

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *manufacturerName;
@property (nonatomic, readonly) NSString *modelNumber;
@property (nonatomic, readonly) NSString *serialNumber;
@property (nonatomic, readonly) NSString *firmwareRevision;
@property (nonatomic, readonly) NSString *hardwareRevision;
@property (nonatomic, readonly) NSString *softwareRevision;
@property (nonatomic, readonly) NSString *systemId;
@property (nonatomic, readonly) NSString *certificationData;
@property (nonatomic, readonly) PnPID pnpId;
@property (nonatomic, readonly) NSInteger batteryLevel;

@property (nonatomic, readonly) BOOL isTipPressed;
@property (nonatomic, readonly) BOOL isEraserPressed;

@end

@protocol FTPenDelegate <NSObject>

- (void)pen:(FTPen *)pen isTipPressedDidChange:(BOOL)isTipPressed;
- (void)pen:(FTPen *)pen isEraserPressedDidChange:(BOOL)isEraserPressed;

@end
