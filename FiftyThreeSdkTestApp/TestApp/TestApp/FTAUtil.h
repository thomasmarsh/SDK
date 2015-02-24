//
//  FTAUtil.h
//  TestApp
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <Foundation/Foundation.h>

// Handy for debugging textures & program objects.
// See: http://www.khronos.org/registry/gles/extensions/EXT/EXT_debug_label.txt
#define DebugGLLabelObject(type, object, label)         \
    {                                                   \
        glLabelObjectEXT((type), (object), 0, (label)); \
    }

// This FTShaderInfo just holds some information about shaders that is populated via
// FTAUtil loadShader.
@interface FTAShaderInfo : NSObject {
}
// Name of files in bundle (fsh & vsh) required.
@property (nonatomic) NSString *shaderName;
// Strings of the attribute names (required).
@property (nonatomic) NSMutableArray *uniformNames;
// Strings of the attribute names (required).
@property (nonatomic) NSMutableArray *attributeNames;

// GL information is filled in when we load the program.
@property (nonatomic) NSMutableArray *attributeLocations;
@property (nonatomic) GLuint glProgram;
@property (nonatomic) NSMutableArray *uniformLocations;

// These two tables are filled in when we load the program.
// NSString -> NSNumbers of uniforms
@property (nonatomic) NSMutableDictionary *uniform;
// NSString -> NSNumbers of uniforms
@property (nonatomic) NSMutableDictionary *attribute;

@end
;

@interface FTAUtil : NSObject
// Loads an OpenGL texture that has a circle with 100% opacity in a square texture with
// width = height = size.
+ (GLuint)loadDiscTextureWithSize:(NSUInteger)h;
+ (FTAShaderInfo *)loadShader:(FTAShaderInfo *)shader;
@end
