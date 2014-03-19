//
//  FTAUtil.m
//  TestApp
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//
#import <CoreGraphics/CoreGraphics.h>

#import "FTAUtil.h"

@interface FTAUtil ()
+ (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file;
+ (BOOL)linkProgram:(GLuint)prog;
+ (BOOL)validateProgram:(GLuint)prog;
@end

@implementation FTShaderInfo

@end

@implementation FTAUtil
+ (GLuint)loadDiscTextureWithSize:(NSUInteger)resolution
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

+ (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file
{
    GLint status;
    const GLchar *source;

    source = (GLchar *)[[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil] UTF8String];
    if (!source) {
        NSLog(@"Failed to load vertex shader");
        return NO;
    }

    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);

#if defined(DEBUG)
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif

    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        glDeleteShader(*shader);
        return NO;
    }

    return YES;
}

+ (BOOL)linkProgram:(GLuint)prog
{
    GLint status;
    glLinkProgram(prog);

#if defined(DEBUG)
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s", log);
        free(log);
    }
#endif

    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (status == 0) {
        return NO;
    }

    return YES;
}

+ (BOOL)validateProgram:(GLuint)prog
{
    GLint logLength, status;

    glValidateProgram(prog);
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s", log);
        free(log);
    }

    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == 0) {
        return NO;
    }

    return YES;
}

+ (FTShaderInfo *)loadShader:(FTShaderInfo *)shader
{
    GLuint vertShader, fragShader;
    NSString *vertShaderPathname, *fragShaderPathname;

    // Uniform etc.. code assumes that shaders have same uniforms and attributes.
    GLuint program = 0;

    program = glCreateProgram();

    // Create and compile vertex shader.
    vertShaderPathname = [[NSBundle mainBundle] pathForResource:shader.shaderName ofType:@"vsh"];
    if (![FTAUtil compileShader:&vertShader type:GL_VERTEX_SHADER file:vertShaderPathname]) {
        NSLog(@"Failed to compile vertex shader");
        return NO;
    }

    // Create and compile fragment shader.
    fragShaderPathname = [[NSBundle mainBundle] pathForResource:shader.shaderName ofType:@"fsh"];
    if (![FTAUtil compileShader:&fragShader type:GL_FRAGMENT_SHADER file:fragShaderPathname]) {
        NSLog(@"Failed to compile fragment shader");
        return NO;
    }

    // Attach vertex shader to program.
    glAttachShader(program, vertShader);

    // Attach fragment shader to program.
    glAttachShader(program, fragShader);

    // Link program.
    if (![FTAUtil linkProgram:program]) {
        NSLog(@"Failed to link program: %d", program);

        if (vertShader) {
            glDeleteShader(vertShader);
            vertShader = 0;
        }
        if (fragShader) {
            glDeleteShader(fragShader);
            fragShader = 0;
        }
        if (program) {
            glDeleteProgram(program);
            program = 0;
        }
        return nil;
    }

    shader.attributeLocations = [@[] mutableCopy];
    shader.attribute = [@{} mutableCopy];
    for(int i = 0; i < [shader.attributeNames count]; ++i)
    {
        GLuint location = glGetAttribLocation(program, [shader.attributeNames[i] UTF8String]);
        [shader.attributeLocations addObject:[NSNumber numberWithInt:location]];

        shader.attribute[shader.attributeNames[i]] = shader.attributeLocations[i];
    }

    // Get uniform locations.
    shader.uniformLocations = [@[] mutableCopy];
    shader.uniform = [@{} mutableCopy];
    for(int i = 0; i < [shader.uniformNames count]; ++i)
    {
        GLuint location = glGetUniformLocation(program, [shader.uniformNames[i] UTF8String]);
        [shader.uniformLocations addObject:[NSNumber numberWithInt:location]];
        shader.uniform[shader.uniformNames[i]] = shader.uniformLocations[i];
    }

    DebugGLLabelObject(GL_PROGRAM_OBJECT_EXT, program, [shader.shaderName UTF8String]);

    shader.glProgram = program;

    // Release vertex and fragment shaders.
    if (vertShader)
    {
        glDetachShader(program, vertShader);
        glDeleteShader(vertShader);
    }
    if (fragShader)
    {
        glDetachShader(program, fragShader);
        glDeleteShader(fragShader);
    }

    return shader;
}

@end
