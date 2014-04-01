//
//  FTADrawer.m
//  TestApp
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#import <GLKit/GLKit.h>

#import "FTADrawer.h"
#import "FTAUtil.h"

#define BUFFER_OFFSET(i) ((char *)NULL + (i))

#define kBrushPixelStep     3

@interface  Stroke : NSObject
@property (nonatomic) NSTimeInterval lastAltered;
// CG Points with inverted Y-axis to match our OpenGL coordinate system.
@property (nonatomic) NSMutableArray *glGeometry;
@property (nonatomic) UIColor *color;
@property (nonatomic) NSInteger drawOrder;
@end

@implementation Stroke
@end

@interface FTADrawer ()
{
    FTAShaderInfo *_pointSpriteShader;
    FTAShaderInfo *_blitShader;

    // Buffers & textures & fbo
    GLuint _vertexBuffer;

    GLuint _blitBuffer;
    GLuint _blitVAO;

    GLuint _pointSpriteTexture;
    GLuint _fbo;
    GLuint _fboTex;
    bool _fboInit;

    // We don't own this fbo.
    GLint _defaultFBO;

    int _textureWidth;
    int _textureHeight;
    GLuint _backingWidth;
    GLuint _backingHeight;
    BOOL _clear;
    BOOL _useBackgroundTexture;

    bool _clearFBO;
}
@property (nonatomic) NSMutableDictionary *scene;
@end

@implementation FTADrawer

- (id)init
{
    if (self = [super init])
    {
        self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];

        if (!self.context) {
            NSLog(@"Failed to create ES context");
        }
        [self setupGL];
    }
    return self;
}

- (void)dealloc
{
    [self tearDownGL];

    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
}

- (void)setScale:(CGFloat)scale
{
    _scale = scale;
    [self updateViewportAndTransforms];
}
- (void)setSize:(CGSize)size
{
    _size = size;
    [self updateViewportAndTransforms];
}

- (void)appendCGPoint:(CGPoint)p forStroke:(NSInteger)strokeId
{
    Stroke *s = self.scene[@(strokeId)];

    if (!s)
    {
        Stroke *s = [[Stroke alloc] init];
        s.lastAltered = [[NSProcessInfo processInfo] systemUptime];
        s.glGeometry = [@[] mutableCopy];
        [s.glGeometry addObject:[NSValue valueWithCGPoint:[self glPointFromCGPoint:p]]];
        s.drawOrder = strokeId;
        s.color = [UIColor whiteColor];

        if (!self.scene)
        {
            self.scene = [@{} mutableCopy];
        }

        [self.scene setObject:s forKey:[NSNumber numberWithInteger:strokeId]];
    }
    else
    {
        s.lastAltered = [[NSProcessInfo processInfo] systemUptime];
        [s.glGeometry addObject:[NSValue valueWithCGPoint:[self glPointFromCGPoint:p]]];
    }
}

- (void)setColor:(UIColor *)c forStroke:(NSInteger)strokeId
{
    Stroke * s = self.scene[@(strokeId)];
    if (s)
    {
        s.lastAltered = [[NSProcessInfo processInfo] systemUptime];
        s.color = c;
    }
    else
    {
        NSLog(@"Not Found!");
    }
}

- (void)removeStroke:(NSInteger)strokeId
{
    [self.scene removeObjectForKey:@(strokeId)];
}
- (void)removeAllStrokes
{
    _fboInit = NO;
    _clearFBO = YES;
    _useBackgroundTexture = NO;
    [self.scene removeAllObjects];
}

- (void)blit
{
    if (!_blitBuffer)
    {
        glBindBuffer(GL_ARRAY_BUFFER, 0);

        glGenVertexArraysOES(1,&_blitVAO);
        glBindVertexArrayOES(_blitVAO);

        glGenBuffers(1, &_blitBuffer);
        glBindBuffer(GL_ARRAY_BUFFER, _blitBuffer);

        // Drawn as a CCW tri-strip hence the following
        // ordering.
        //
        //  2 --4
        //  | \ |
        //  1-- 3
        static GLfloat squareVertices[4*4] =
        {
            0.0f, 0.0f,      0.0f, 0.0f, // x y u v
            0.0f,  768.0,    0.0f, 1.0f,
            1024.0f, 0.0f,   1.0f, 0.0f,
            1024.0f, 768.0,  1.0f, 1.0f
        };
        static BOOL scaled = NO;
        if (!scaled)
        {
            for(int i = 0; i < 4; ++i)
            {
                squareVertices[i*4 + 0] *= self.scale;
                squareVertices[i*4 + 1] *= self.scale;
            }
            scaled = YES;
        }

        // Load data to the Vertex Buffer Object
        glBufferData(GL_ARRAY_BUFFER, 4*4*sizeof(GLfloat), squareVertices, GL_STATIC_DRAW);

        glEnableVertexAttribArray([_blitShader.attribute[@"inVertex"] intValue]);
        glVertexAttribPointer([_blitShader.attribute[@"inVertex"] intValue], 2, GL_FLOAT, GL_FALSE, 4*sizeof(GLfloat), 0);

        glEnableVertexAttribArray([_blitShader.attribute[@"inTex"] intValue]);
        glVertexAttribPointer([_blitShader.attribute[@"inTex"] intValue], 2, GL_FLOAT, GL_FALSE, 4*sizeof(GLfloat), (const void*) (2*sizeof(GLfloat)));

        glBindVertexArrayOES(0);
        glBindBuffer(GL_ARRAY_BUFFER, 0);
    }

    glUseProgram(_blitShader.glProgram);

    // Viewport stuff is setup in updateTransforms. For simplicity both the
    // point sprite and blit shader use the same coordinate spaces for their geometry.
    glDisable(GL_DEPTH_TEST);

    // Enable blending and set a blending function appropriate for premultiplied alpha pixel data
    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);

    glActiveTexture(GL_TEXTURE0);
    glUniform1i([_blitShader.uniform[@"texture"] intValue], 0);
    glBindTexture(GL_TEXTURE_2D, _fboTex);
    glBindVertexArrayOES(_blitVAO);

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    glBindVertexArrayOES(0);

    glDisableVertexAttribArray([_blitShader.attribute[@"inTex"] intValue]);
    glDisableVertexAttribArray([_blitShader.attribute[@"inVertex"] intValue]);
}

- (void)draw
{
    [self setupFBO];

    //
    // The rendering proceeds as follows
    //  (1) Clear
    //  (2) Render any contents that we've got saved to a texture.
    //  (3) Render any strokes that are "active" and either subject to
    //      appending new geometry or are subject to re-classification.
    //  (4) Update our saved texture with any strokes that are no-longer active.

    glClearColor(0.9f, 0.9f, 0.9f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    // If we've rendered any contents into the fboTexture we render
    // that first.
    if (_useBackgroundTexture)
    {
        [self blit];
    }

    glUseProgram(_pointSpriteShader.glProgram);
    [self setupPointSpriteShaderState];

    // We sort the scene on draw order.
    NSArray *scene = [_scene allValues];
    NSArray *sortedScene = [scene sortedArrayUsingComparator:
                            ^NSComparisonResult(id obj1, id obj2) {
                                Stroke *lhs = obj1;
                                Stroke *rhs = obj2;

                                if (lhs.drawOrder < rhs.drawOrder)
                                {
                                    return  -1;
                                }
                                else if (rhs.drawOrder == lhs.drawOrder)
                                {
                                    return 0;
                                }
                                else
                                {
                                    return 1;
                                }
                            }];

    for(Stroke *v in sortedScene)
    {
        if ([v.glGeometry count] >= 2)
        {
            [self setBrushColor:v.color];

            {
                // Since each of these issues a draw call, this is quite expensive. We could
                // do a lot of optimization here but it would make the code
                // much less readable.
                for(NSInteger i = 0; i < [v.glGeometry count]-1; ++i)
                {
                    [self renderLineFromPoint:[(NSValue*)v.glGeometry[i] CGPointValue]
                                      toPoint:[(NSValue*)v.glGeometry[i+1] CGPointValue]];
                }
            }
        }
        else if ([v.glGeometry count] == 1)
        {
            [self renderLineFromPoint:[(NSValue*)v.glGeometry[0] CGPointValue]
                              toPoint:[(NSValue*)v.glGeometry[0] CGPointValue]];
        }
    }

    // OK commit all strokes that are no longer "active"

    NSTimeInterval now = [[NSProcessInfo processInfo] systemUptime];
    NSMutableArray *oldScene = [@[] mutableCopy];
    for (Stroke *v in sortedScene)
    {
        // Don't bother keeping older strokes we "commit" them to a texture
        // if (a) they haven't been reclassified.
        //    (b) they haven't been appended too recently.
        BOOL old = (now - v.lastAltered) > 0.5;
        if (old)
        {
            [_scene removeObjectForKey:@(v.drawOrder)];
            [oldScene addObject:v];
        }
        else
        {
            break;
        }
    }
    if ([oldScene count] >= 1)
    {
        glBindFramebuffer(GL_FRAMEBUFFER, _fbo);

        glViewport(0,0, _backingWidth, _backingHeight);

        if (!_useBackgroundTexture)
        {
            if (_clearFBO)
            {
                glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
                glClear(GL_COLOR_BUFFER_BIT);
                _clearFBO = NO;
            }
            _useBackgroundTexture = YES;
        }

        glUseProgram(_pointSpriteShader.glProgram);

        [self setupPointSpriteShaderState];

        for(Stroke *v in oldScene)
        {
            if ([v.glGeometry count] >= 2)
            {
                [self setBrushColor:v.color];
                {
                    // Since each of these issues a draw call, this is quite expensive. We could
                    // do a lot of optimization here but it would make the code
                    // much less readable.
                    for(NSInteger i = 0; i < [v.glGeometry count]-1; ++i)
                    {
                        [self renderLineFromPoint:[(NSValue*)v.glGeometry[i] CGPointValue]
                                          toPoint:[(NSValue*)v.glGeometry[i+1] CGPointValue]];
                    }
                }
            }
            else if ([v.glGeometry count] == 1)
            {
                [self renderLineFromPoint:[(NSValue*)v.glGeometry[0] CGPointValue]
                                  toPoint:[(NSValue*)v.glGeometry[0] CGPointValue]];
            }
        }

        glBindFramebuffer(GL_FRAMEBUFFER, _defaultFBO);
        [self.view bindDrawable];
    }
}

- (CGPoint)glPointFromCGPoint:(CGPoint)location
{
    location.y = self.size.height - location.y;
    location.x *= self.scale;
    location.y *= self.scale;
    return location;
}
#pragma mark - OpenGL ES Drawing
// Drawings a line onscreen based on where the user touches
- (void)renderLineFromPoint:(CGPoint)start toPoint:(CGPoint)end
{
    static GLfloat*     vertexBuffer = NULL;
    static NSUInteger   vertexMax = 64;
    NSUInteger          vertexCount = 0,
    count,
    i;

    // Allocate vertex array buffer
    if (vertexBuffer == NULL)
    {
        vertexBuffer = malloc(vertexMax * 2 * sizeof(GLfloat));
    }

    // Add points to the buffer so there are drawing points every X pixels
    count = MAX(ceilf(sqrtf((end.x - start.x) * (end.x - start.x) + (end.y - start.y) * (end.y - start.y)) / kBrushPixelStep), 1);

    for (i = 0; i < count; ++i)
    {
        if(vertexCount == vertexMax)
        {
            vertexMax = 2 * vertexMax;
            vertexBuffer = realloc(vertexBuffer, vertexMax * 2 * sizeof(GLfloat));
        }

        vertexBuffer[2 * vertexCount + 0] = start.x + (end.x - start.x) * ((GLfloat)i / (GLfloat)count);
        vertexBuffer[2 * vertexCount + 1] = start.y + (end.y - start.y) * ((GLfloat)i / (GLfloat)count);
        ++vertexCount;
    }

    // Load data to the Vertex Buffer Object
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, vertexCount*2*sizeof(GLfloat), vertexBuffer, GL_DYNAMIC_DRAW);

    glEnableVertexAttribArray([_pointSpriteShader.attribute[@"inVertex"] intValue]);
    glVertexAttribPointer([_pointSpriteShader.attribute[@"inVertex"] intValue], 2, GL_FLOAT, GL_FALSE, 0, 0);

    // We don't need the use program as there's only ever 1 shader in use.
    glDrawArrays(GL_POINTS, 0, (int)vertexCount);

    glDisableVertexAttribArray([_pointSpriteShader.attribute[@"inVertex"] intValue]);
}

#pragma mark - OpenGL ES shader state changes
- (void)setBrushColor:(UIColor *)color
{
    GLfloat brushColor[4];
    CGFloat colors[4];

    [color getRed:colors green:colors+1 blue:colors+2 alpha:colors+3];

    brushColor[0] = colors[0]; // On 64 bit GLFloat != CGFloat.
    brushColor[1] = colors[1];
    brushColor[2] = colors[2];
    brushColor[3] = colors[3];

    glUseProgram(_pointSpriteShader.glProgram);
    glUniform4fv([_pointSpriteShader.uniform[@"color"] intValue], 1, brushColor);
}
- (void)setPointSize
{
    glUseProgram(_pointSpriteShader.glProgram);
    glUniform1f([_pointSpriteShader.uniform[@"pointSize"] intValue], 8.0f);
}
- (void)updateViewportAndTransforms
{
    float w = self.size.width;
    float h = self.size.height;

    _backingWidth = w * self.scale;
    _backingHeight = h * self.scale;

    // Update projection matrix , the model is the identity.
    GLKMatrix4 projectionMatrix = GLKMatrix4MakeOrtho(0, _backingWidth, 0, _backingHeight, -1, 1);

    glUseProgram(_blitShader.glProgram);
    glUniformMatrix4fv([_blitShader.uniform[@"MVP"] intValue], 1, GL_FALSE, projectionMatrix.m);

    glUseProgram(_pointSpriteShader.glProgram);
    glUniformMatrix4fv([_pointSpriteShader.uniform[@"MVP"] intValue], 1, GL_FALSE, projectionMatrix.m);

    // Update viewport
    glViewport(0, 0, _backingWidth, _backingHeight);
}

#pragma mark - FBO setup
// intialize FBO
- (void)setupFBO
{
    if (!_fboInit)
    {
        _fboInit = YES;
        _clearFBO = YES;
        GLuint fbo_width = _backingWidth;
        GLuint fbo_height = _backingHeight;

        if (_fboTex)
        {
            glDeleteTextures(1, &_fboTex);
            _fboTex = 0;
        }
        if (_fbo)
        {
            glDeleteFramebuffers(1, &_fbo);
            _fbo = 0;
        }

        glGetIntegerv(GL_FRAMEBUFFER_BINDING, &_defaultFBO);

        glGenFramebuffers(1, &_fbo);
        glGenTextures(1, &_fboTex);

        glBindFramebuffer(GL_FRAMEBUFFER, _fbo);
        DebugGLLabelObject(GL_FRAMEBUFFER, _fbo, "fbo");

        glBindTexture(GL_TEXTURE_2D, _fboTex);
        DebugGLLabelObject(GL_TEXTURE, _fboTex, "fboText");

        glTexImage2D( GL_TEXTURE_2D,
                     0,
                     GL_RGBA,
                     fbo_width, fbo_height,
                     0,
                     GL_RGBA,
                     GL_UNSIGNED_BYTE,
                     NULL);

        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _fboTex, 0);

        // FBO status check
        GLenum status;
        status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
        switch(status)
        {
            case GL_FRAMEBUFFER_COMPLETE:
                NSLog(@"fbo complete");
                break;

            case GL_FRAMEBUFFER_UNSUPPORTED:
                NSLog(@"fbo unsupported");
                break;

            default:
                /* programming error; will fail on all hardware */
                NSLog(@"Framebuffer Error");
                break;
        }

        glBindTexture(GL_TEXTURE_2D, 0);
        glBindFramebuffer(GL_FRAMEBUFFER, _defaultFBO);
        [self.view bindDrawable];
    }
}

#pragma mark -  OpenGL ES 2 shader configration.
- (void)setupPointSpriteShaderState
{
    glUseProgram(_pointSpriteShader.glProgram);

    glActiveTexture(GL_TEXTURE0);
    glUniform1i([_pointSpriteShader.uniform[@"texture"] intValue], 0);
    glBindTexture(GL_TEXTURE_2D, _pointSpriteTexture);
    DebugGLLabelObject(GL_TEXTURE, _pointSpriteTexture, "pointSpriteTexture");

    // Disable depth testing.
    glDisable(GL_DEPTH_TEST);

    // Enable blending and set a blending function appropriate for premultiplied alpha pixel data
    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);

    [self setPointSize];
    [self updateViewportAndTransforms];
}

- (void)setupGL
{
    [EAGLContext setCurrentContext:self.context];

    // Create a Vertex Buffer Object to hold our data
    glGenBuffers(1, &_vertexBuffer);

    // Load the brush texture
    _textureHeight = _textureWidth = 128;
    _pointSpriteTexture = [FTAUtil loadDiscTextureWithSize:_textureWidth];

    // Load shaders.
    [self loadShaders];

    [self setupPointSpriteShaderState];
}

- (void)tearDownGL
{
    [EAGLContext setCurrentContext:self.context];

    glDeleteBuffers(1, &_vertexBuffer);
    glDeleteTextures(1, &_pointSpriteTexture);
    glDeleteBuffers(1, &_blitBuffer);
    glDeleteVertexArraysOES(1, &_blitVAO);
    glDeleteTextures(1, &_fboTex);
    glDeleteFramebuffers(1, &_fbo);
    if (_pointSpriteShader)
    {
        if (_pointSpriteShader.glProgram)
        {
            glDeleteProgram(_pointSpriteShader.glProgram);
        }
        _pointSpriteShader = nil;
    }

    if (_blitShader)
    {
        if (_blitShader.glProgram)
        {
            glDeleteProgram(_blitShader.glProgram);
        }
        _blitShader = nil;
    }
}

- (BOOL)loadShaders
{
    _pointSpriteShader = [[FTAShaderInfo alloc] init];
    _pointSpriteShader.shaderName = @"TrivialPointSprite";
    _pointSpriteShader.uniformNames = [@[@"MVP", @"pointSize", @"color", @"texture"] mutableCopy];
    _pointSpriteShader.attributeNames = [@[@"inVertex"] mutableCopy];
    _pointSpriteShader = [FTAUtil loadShader:_pointSpriteShader];

    _blitShader = [[FTAShaderInfo alloc] init];
    _blitShader.shaderName = @"TrivialBlit";
    _blitShader.uniformNames = [@[@"texture"] mutableCopy];
    _blitShader.attributeNames = [@[@"inVertex", @"inTex"] mutableCopy];
    _blitShader = [FTAUtil loadShader:_blitShader];

    return _blitShader && _pointSpriteShader;
}

@end
