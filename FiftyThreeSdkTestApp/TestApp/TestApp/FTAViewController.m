//
//  FTAViewController.m
//  TestApp
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#import "FiftyThreeSdk/FiftyThreeSdk.h"
#import "FTASettingsViewController.h"
#import "FTAUtil.h"
#import "FTAViewController.h"

#define BUFFER_OFFSET(i) ((char *)NULL + (i))

#define kBrushPixelStep     3

// see: http://www.khronos.org/registry/gles/extensions/EXT/EXT_debug_label.txt
#define DebugGLLabelObject(type, object, label)\
{\
glLabelObjectEXT((type),(object), 0, (label));\
}

@interface  Stroke : NSObject
@property (nonatomic) NSTimeInterval lastAppended;
@property (nonatomic) NSTimeInterval lastReclassified;
// CG Points with inverted Y-axis to match our OpenGL coordinate system.
@property (nonatomic) NSMutableArray *glGeometry;
@property (nonatomic) UIColor *color;
@property (nonatomic) NSInteger drawOrder;
@end

@implementation Stroke
@end

@interface FTAViewController () <FTTouchClassificationsChangedDelegate,
                                 FTPenManagerDelegate,
                                 UIPopoverControllerDelegate> {

    FTShaderInfo *_pointSpriteShader;
    FTShaderInfo *_blitShader;

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

    // The scene is a dictionary of strokes indexed by
    // FT touch id.
    NSMutableDictionary *_scene;

    NSDictionary *_strokeColors;
}
@property (nonatomic) EAGLContext *context;
@property (nonatomic) GLKBaseEffect *effect;
@property (nonatomic) UIToolbar *bar;
@property (nonatomic) BOOL isPencilEnabled;

@property (nonatomic) UIPopoverController *popover;
@property (nonatomic) FTASettingsViewController *popoverContents;

- (void)setupGL;
- (void)tearDownGL;

- (BOOL)loadShaders;
@end

@implementation FTAViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    // We use a basic GL view for rendering some ink and showing
    // touch classifications. Most of the GL related code is towards the buttom.
    // the interesting bits are touch processing, and the classification changed events.
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];

    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }

    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormatNone;

    // We add a number of bar buttons for testing.
    // (1) A button to tear down FTPenManager
    // (2) A button to startup FTPenManager
    // (3) A Button to clear page of ink.
    // (4) A button to show a popover with Pen status. This uses the FTPenInformation API to
    //     populate a table view. See FTASettingsViewController.
    self.bar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, MAX(self.view.frame.size.width,self.view.frame.size.height), 44)];

    UIBarButtonItem *button1 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop
                                                                             target:self
                                                                             action:@selector(shutdownFTPenManager:)];
    UIBarButtonItem *button2 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay
                                                                             target:self
                                                                             action:@selector(initializeFTPenManager:)];

    UIBarButtonItem *spacer1 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                             target:nil
                                                                             action:nil];

    UIBarButtonItem *button3 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                             target:self
                                                                             action:@selector(clearScene:)];

    UIBarButtonItem *button4 = [[UIBarButtonItem alloc] initWithTitle:@"   Info   "
                                                                style:UIBarButtonItemStylePlain
                                                               target:self
                                                               action:@selector(showInfo:)];

    [self.bar setItems:@[button1, button2, spacer1, button3, button4]];
    self.bar.barStyle = UIBarStyleBlack;
    self.bar.translucent = NO;

    [self.view addSubview:self.bar];
    self.isPencilEnabled = NO;

    // Defaults to 30, we ant to catch any performance problems so we crank it up.
    self.preferredFramesPerSecond = 60;

    _strokeColors =
    @{
      @(FTTouchClassificationUnknownDisconnected) : [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.3],
      @(FTTouchClassificationUnknown) : [UIColor colorWithRed:0.3 green:0.4 blue:0.1 alpha:0.5],
      @(FTTouchClassificationPen) : [UIColor colorWithRed:0.1 green:0.3 blue:0.9 alpha:0.5],
      @(FTTouchClassificationEraser) : [UIColor colorWithRed:0.9 green:0.1 blue:0.0 alpha:0.5],
      @(FTTouchClassificationFinger) : [UIColor colorWithRed:0.0 green:0.9 blue:0.0 alpha:0.5],
      @(FTTouchClassificationPalm) : [UIColor colorWithRed:0.1 green:0.2 blue:0.1 alpha:0.5]
    };

    // Multi touch is required for processing palm and pen touches.
    // See handleTouches below.
    [self.view setMultipleTouchEnabled:YES];
    [self.view setUserInteractionEnabled:YES];
    [self.view setExclusiveTouch:NO];

    [self setupGL];
}
- (void)dealloc
{
    [self tearDownGL];

    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
}
#pragma mark - Bar Button handlers.
- (void)showInfo:(id)sender
{
    UIBarButtonItem *barButton = (UIBarButtonItem*)sender;

    self.popover = nil;
    self.popoverContents = nil;

    if (self.isPencilEnabled)
    {
        self.popoverContents = [[FTASettingsViewController alloc] init];
        self.popoverContents.info = [FTPenManager sharedInstance].info;

        self.popover = [[UIPopoverController alloc] initWithContentViewController:self.popoverContents];
        self.popover.delegate = self;
        [self.popover presentPopoverFromBarButtonItem:barButton permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
    }
}
- (void)clearScene:(id)sender
{
    _fboInit = NO;
    _clearFBO = YES;
    _useBackgroundTexture = NO;
    [_scene removeAllObjects];
}
- (void)shutdownFTPenManager:(id)sender
{
    // Make sure you don't retain any instances of FTPenManager
    // as that will be dealloced to free up CoreBluetooth for other
    // stylus SDKs.
    [[FTPenManager sharedInstance] shutdown];
    self.isPencilEnabled = NO;
    if (self.popover)
    {
        [self.popover dismissPopoverAnimated:NO];
        self.popover = nil;
    }
}

- (void)initializeFTPenManager:(id)sender
{
    UIView *connectionView = [[FTPenManager sharedInstance] pairingButtonWithStyle:FTPairingUIStyleDark
                                                        andTintColor:nil
                                                            andFrame:CGRectZero];

    connectionView.frame = CGRectMake(0.0f, 768 - 100, connectionView.frame.size.width, connectionView.frame.size.height);
    [self.view addSubview:connectionView];

    [FTPenManager sharedInstance].classifier.delegate = self;
    [FTPenManager sharedInstance].delegate = self;

    // You would only uncomment this if you want to drive the animations & classification
    // from your displayLink, see also the update method in this view controller.
    //[FTPenManager sharedInstance].automaticUpdatesEnabled = NO;

    self.isPencilEnabled = YES;
}

#pragma mark - FTTouchClassificationDelegate
- (void)classificationsDidChangeForTouches:(NSSet *)touches;
{
    for(FTTouchClassificationInfo *info in touches)
    {
        NSLog(@"Touch %d was %d now %d", info.touchId, info.oldValue, info.newValue);
        Stroke * s = _scene[@(info.touchId)];
        if (s)
        {
            s.color = _strokeColors[@(info.newValue)];
        }
        else
        {
            NSLog(@"Not Found!");
        }
    }
}

#pragma mark - GLKView and GLKViewController delegate methods

- (void)update
{
// You'd only uncomment this if you've set FTPenManager's automaticUpdatesEnabled to NO.
//    if (self.isPencilEnabled)
//    {
//        [[FTPenManager sharedInstance] update];
//    }
}

- (CGPoint)glPointFromEvent:(UIEvent *)event andTouch:(UITouch *)touch
{
    CGRect   bounds = [self.view bounds];
    // Convert touch point from UIView referential to OpenGL one (upside-down flip)
    CGPoint location = [touch locationInView:self.view];
    location.y = bounds.size.height - location.y;
    return location;
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
        static const GLfloat squareVertices[4*4] =
        {
            0.0f, 0.0f,      0.0f, 0.0f, // x y u v
            0.0f,  768.0,    0.0f, 1.0f,
            1024.0f, 0.0f,   1.0f, 0.0f,
            1024.0f, 768.0,  1.0f, 1.0f
        };

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

#pragma mark - GLKView delegate
- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
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
        BOOL old = (now - v.lastReclassified) > 0.5 && (now - v.lastAppended) > 0.5;
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
        // reset to main framebuffer
        [((GLKView *) self.view) bindDrawable];
    }
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

    // Convert locations from Points to Pixels
    CGFloat scale = self.view.contentScaleFactor;

    start.x *= scale;
    start.y *= scale;
    end.x *= scale;
    end.y *= scale;

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
    [color getRed:brushColor green:brushColor+1 blue:brushColor+2 alpha:brushColor+3];
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
    // TODO what is up with GLKView's w/h

    CGRect rect = [UIScreen mainScreen].bounds;

    float w = MAX(rect.size.height, rect.size.width);
    float h = MIN(rect.size.height, rect.size.width);

    _backingWidth = w * self.view.contentScaleFactor;
    _backingHeight = h * self.view.contentScaleFactor;

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
        [((GLKView *) self.view) bindDrawable];
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

- (void)viewWillLayoutSubviews
{
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
    _pointSpriteShader = [[FTShaderInfo alloc] init];
    _pointSpriteShader.shaderName = @"TrivialPointSprite";
    _pointSpriteShader.uniformNames = [@[@"MVP", @"pointSize", @"color", @"texture"] mutableCopy];
    _pointSpriteShader.attributeNames = [@[@"inVertex"] mutableCopy];
    _pointSpriteShader = [FTAUtil loadShader:_pointSpriteShader];

    _blitShader = [[FTShaderInfo alloc] init];
    _blitShader.shaderName = @"TrivialBlit";
    _blitShader.uniformNames = [@[@"texture"] mutableCopy];
    _blitShader.attributeNames = [@[@"inVertex", @"inTex"] mutableCopy];
    _blitShader = [FTAUtil loadShader:_blitShader];

    return _blitShader && _pointSpriteShader;
}

#pragma mark - Touch Handling

// Since we've turned on multi touch we may get
// more than one touch in Began/Moved/Ended. Most iOS samples show something like
// UITouch * t = [touches anyObject];
// This isn't correct if you can have multiple touches and multipleTouchEnabled set to YES.
- (void)handleTouches:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (_isPencilEnabled)
    {
        for (UITouch* touch in touches)
        {
            NSInteger k = [[FTPenManager sharedInstance].classifier idForTouch:touch];

            if (touch.phase == UITouchPhaseBegan)
            {
                Stroke *s = [[Stroke alloc] init];
                s.color = _strokeColors[@(FTTouchClassificationUnknownDisconnected)];
                s.lastAppended = event.timestamp;
                s.lastReclassified = event.timestamp;
                s.glGeometry = [@[] mutableCopy];
                [s.glGeometry addObject:[NSValue valueWithCGPoint:[self glPointFromEvent:event andTouch:touch]]];
                s.drawOrder = k;

                if (!_scene)
                {
                    _scene = [@{} mutableCopy];
                }

                [_scene setObject:s forKey:[NSNumber numberWithInt:k]];

            }
            else if(touch.phase == UITouchPhaseMoved)
            {
                Stroke *s = _scene[@(k)];
                s.lastAppended = event.timestamp;
                [s.glGeometry  addObject:[NSValue valueWithCGPoint:[self glPointFromEvent:event andTouch:touch]]];

            }
            else if(touch.phase == UITouchPhaseEnded)
            {
                Stroke *s = _scene[@(k)];
                s.lastAppended = event.timestamp;
                [s.glGeometry  addObject:[NSValue valueWithCGPoint:[self glPointFromEvent:event andTouch:touch]]];
            }
            else if (touch.phase == UITouchPhaseCancelled)
            {
                [_scene removeObjectForKey:@(k)];
            }
        }
    }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self handleTouches:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self handleTouches:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self handleTouches:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self handleTouches:touches withEvent:event];
}

#pragma mark - View Controller boiler plate.

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];

    if ([self isViewLoaded] && ([[self view] window] == nil)) {
        self.view = nil;

        [self tearDownGL];

        if ([EAGLContext currentContext] == self.context) {
            [EAGLContext setCurrentContext:nil];
        }
        self.context = nil;
    }
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

#pragma mark - FTPenManagerDelegate
- (void)penManagerNeedsUpdateDidChange;
{
    NSLog(@"penManagerNeedsUpdateDidChange %@", [[FTPenManager sharedInstance] needsUpdate]? @"YES":@"NO");
}
// Invoked when the connection state is altered.
- (void)penManagerConnectionStateDidChange:(FTPenManagerState)state
{
    NSLog(@"connection did change %@", FTPenManagerStateToString(state));
}

// Invoked when any of the BTLE information is read off the pen. See FTPenInformation.
- (void)penInformationDidChange
{
    if (self.popoverContents)
    {
        self.popoverContents.info = [FTPenManager sharedInstance].info;
        [self.popoverContents.tableView reloadData];
    }
}

#pragma mark - UIPopoverViewControllerDelegate

- (BOOL)popoverControllerShouldDismissPopover:(UIPopoverController *)popoverController
{
    return YES;
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    self.popoverContents = nil;
    self.popover = nil;
}

@end
