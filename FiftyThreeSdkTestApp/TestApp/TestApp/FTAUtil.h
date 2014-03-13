//
//  FTAUtil.h
//  TestApp
//
//  Created by Peter Sibley on 3/13/14.
//  Copyright (c) 2014 FiftyThree. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FTAUtil : NSObject
// Loads a opengl texture that has a circle with 100% opacity in a square texture with
// width = height = size.
+ (GLuint) loadDiscTextureWithSize:(NSUInteger)h;
@end
