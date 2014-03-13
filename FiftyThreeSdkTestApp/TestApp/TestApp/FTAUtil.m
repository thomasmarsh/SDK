//
//  FTAUtil.m
//  TestApp
//
//  Created by Peter Sibley on 3/13/14.
//  Copyright (c) 2014 FiftyThree. All rights reserved.
//
#import <CoreGraphics/CoreGraphics.h>

#import "FTAUtil.h"

@implementation FTAUtil
+ (GLuint) loadDiscTextureWithSize:(NSUInteger)resolution
{
    // make bitmap context
    
    CGColorSpaceRef space = CGColorSpaceCreateDeviceGray();
    CGContextRef context = CGBitmapContextCreate(NULL, resolution, resolution, 8, 1 * resolution, space, kCGImageAlphaOnly);
    CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
    CGColorSpaceRelease(space);
    
    //Clear context
    CGContextClearRect(context, CGRectMake(0, 0, resolution, resolution));
    CGContextSetGrayFillColor(context, 1.0, 1.0);
    
    // Draw circle.
    float halfSize = resolution/2.0;
    CGContextAddArc(context, halfSize, halfSize, halfSize - 0.5f, 0, M_PI * 2, false);
    CGContextFillPath(context);
    
    // Grab data.
    void* data = CGBitmapContextGetData(context);
    
    // Upload pixel data to GPU texture.
    GLuint texture;
    glGenTextures(1, &texture);
    glBindTexture(GL_TEXTURE_2D, texture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D,
                 0,
                 GL_ALPHA,
                 (GLuint)resolution,
                 (GLuint)resolution,
                 0,
                 GL_ALPHA,
                 GL_UNSIGNED_BYTE,
                 data);
    
    CGContextRelease(context);
    
    return texture;
}
@end
