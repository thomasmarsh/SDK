//
//  FTADrawer.h
//  TestApp
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <Foundation/Foundation.h>
#import <GLKit/GLKit.h>

// This utility class hides the details of OpenGL rendering & our scene.
// Here strokeId, is mapped to FTTouchId.

@interface FTADrawer : NSObject
- (void)appendCGPoint:(CGPoint)p forStroke:(NSInteger)strokeId;
- (void)setColor:(UIColor *)c forStroke:(NSInteger)strokeId;
- (void)removeStroke:(NSInteger)strokeId;
- (void)removeAllStrokes;
- (void)draw;
@property (nonatomic) EAGLContext *context;
@property (nonatomic) CGSize size;
@property (nonatomic) CGFloat scale;
@property (nonatomic) GLKView *view;
@end
