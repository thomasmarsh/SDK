//
//  DrawingView.m
//  FiftyThreeSdkTestApp
//
//  Created by Adam on 3/26/13.
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "DrawingView.h"
#include "Canvas/GLCanvasController.h"
#include "Common/InputSample.h"

using namespace fiftythree::common;

@interface DrawingView ()

@property (nonatomic) GLCanvasController *canvasController;
@property (nonatomic) BOOL dirty;

@end

@implementation DrawingView


- (void)awakeFromNib
{
//    self.backgroundColor = [UIColor clearColor];
//    self.layer.cornerRadius = 15.f;
    self.clipsToBounds = YES;
    
    // Create the canvas controller and add its view.
    self.canvasController = [[GLCanvasController alloc] initWithFrame:self.frame
                                                             andScale:[UIScreen mainScreen].scale];
    
    self.canvasController.view.hidden = YES;
    self.canvasController.paused = YES;
    [self addSubview:self.canvasController.view];
    
    [self reset];
}

- (void)dealloc
{
    self.canvasController.paused = YES;
}

- (void)setBrushType:(NSString *)brushType
{
    _brushType = [brushType copy];
    
    [self.canvasController setBrush:brushType];
}

- (void)clear
{
    if (self.dirty)
    {
        self.canvasController.paused = YES;
        self.canvasController.view.hidden = YES;
        self.dirty = NO;
    }
}

- (void)reset
{
    [self clear];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    // Ok, we're starting a stroke. If we haven't already done a stroke...
    if (!self.dirty)
    {
        self.dirty = YES;
    }
    
    DebugAssert(touches.count == 1);
    UITouch *touch = [touches anyObject];
    [self.canvasController beginStroke:InputSampleFromCGPoint([touch locationInView:self],
                                                              touch.timestamp)];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    DebugAssert([touches count] == 1);
    UITouch *touch = [touches anyObject];
    [self.canvasController continueStroke:InputSampleFromCGPoint([touch locationInView:self],
                                                                 touch.timestamp)];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    DebugAssert([touches count] == 1);
    UITouch *touch = [touches anyObject];
    [self.canvasController endStroke:InputSampleFromCGPoint([touch locationInView:self],
                                                            touch.timestamp)];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    DebugAssert([touches count] == 1);
    [self.canvasController cancelStroke];
}


@end

