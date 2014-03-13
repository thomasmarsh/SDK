//
//  FTAViewController.m
//  TestApp
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//



#import "FiftyThreeSdk/FiftyThreeSdk.h"
#import "FTAViewController.h"
#import "FTAUtil.h"

// This uses portions of shaders from Apple's GLPaint Sample & Apple's starter GLKit project.


#define BUFFER_OFFSET(i) ((char *)NULL + (i))


#define kBrushOpacity       (1.0 / 3.0)
#define kBrushPixelStep     3

// Shaders enums
enum
{
    PROGRAM_POINT,
    NUM_PROGRAMS
};

enum
{
    UNIFORM_MVP,
    UNIFORM_POINT_SIZE,
    UNIFORM_VERTEX_COLOR,
    UNIFORM_TEXTURE,
    NUM_UNIFORMS
};

GLint uniforms[NUM_UNIFORMS];

enum
{
    ATTRIB_VERTEX,
    NUM_ATTRIBS
};


GLint attributes[NUM_ATTRIBS];

// Must match Shader.fsh/vsh.
static const GLchar *attribName[NUM_ATTRIBS] =
{
    "inVertex"
};
static const GLchar *uniformName[NUM_UNIFORMS] =
{
    "MVP", "pointSize", "color", "texture"
};


@interface FTAViewController () <FTTouchClassificationsChangedDelegate> {
    
    // OpenGL resources.
    GLuint _program;
    GLuint _vertexBuffer;
    GLuint _texture;
    
    int _textureWidth;
    int _textureHeight;
    GLuint _backingWidth;
    GLuint _backingHeight;
    BOOL _clear;
    
    // A list of points to render.
    NSMutableArray *_pointsToRender;
}
@property (nonatomic) EAGLContext *context;
@property (nonatomic) GLKBaseEffect *effect;
@property (nonatomic) UIToolbar *bar;
@property (nonatomic) BOOL isPencilEnabled;

- (void)setupGL;
- (void)tearDownGL;

- (BOOL)loadShaders;
- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file;
- (BOOL)linkProgram:(GLuint)prog;
- (BOOL)validateProgram:(GLuint)prog;
@end

@implementation FTAViewController


- (void)viewDidLoad
{
    [super viewDidLoad];

    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];

    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }

    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormatNone;
    
 
    self.bar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 44)];
    [self.bar setBarStyle:UIBarStyleBlack];

    UIBarButtonItem *button1 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop
                                                                             target:self
                                                                             action:@selector(shutdownFTPenManager:)];
    UIBarButtonItem *button2 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay
                                                                             target:self
                                                                             action:@selector(initializeFTPenManager:)];
    [self.bar setItems:@[button1, button2]];
    [self.view addSubview:self.bar];
    self.isPencilEnabled = NO;

    self.preferredFramesPerSecond = 60;
    
    _pointsToRender = [@[] mutableCopy];
    
    [self setupGL];
}

- (void)shutdownFTPenManager:(id)sender
{
    [[FTPenManager sharedInstance] shutdown];
    self.isPencilEnabled = NO;
}

- (void)initializeFTPenManager:(id)sender
{
    UIView *v = [[FTPenManager sharedInstance] pairingButtonWithStye:FTPairingUIStyleDark
                                                        andTintColor:nil
                                                            andFrame:CGRectZero];

    v.frame = CGRectMake(0.0f, 768 - 100, v.frame.size.width, v.frame.size.height);
    [self.view addSubview:v];

    [FTPenManager sharedInstance].classifier.delegate = self;
    self.isPencilEnabled = YES;
}
- (void)dealloc
{
    [self tearDownGL];

    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
}

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

- (void)setupGL
{
    [EAGLContext setCurrentContext:self.context];

    // Create a Vertex Buffer Object to hold our data
    glGenBuffers(1, &_vertexBuffer);
    
    // Load the brush texture
    _textureHeight = _textureWidth = 128;
    _texture = [FTAUtil loadDiscTextureWithSize:_textureWidth];
    glBindTexture(GL_TEXTURE0, _texture);

    // Load shaders.
    [self loadShaders];
    
    // Disable depth testing.
    glDisable(GL_DEPTH_TEST);
    
    // Enable blending and set a blending function appropriate for premultiplied alpha pixel data
    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    
    [self setBrushColorWithRed:0.0 green:0.9 blue:0.1];
    [self setPointSize];
}

- (void)viewWillLayoutSubviews
{
    [self updateViewportAndTransforms];
}

- (void)tearDownGL
{
    [EAGLContext setCurrentContext:self.context];

    glDeleteBuffers(1, &_vertexBuffer);
    glDeleteTextures(1, &_texture);
    
    if (_program) {
        glDeleteProgram(_program);
        _program = 0;
    }
}

#pragma mark - FTTouchClassificationDelegate
- (void)classificationsDidChangeForTouches:(NSSet *)touches;
{
    for(FTTouchClassificationInfo *info in touches)
    {
        NSLog(@"Touch %x was %d now %d", (unsigned int)info.touch, info.oldValue, info.newValue);
    }
}

#pragma mark - GLKView and GLKViewController delegate methods

- (void)update
{
    if (self.isPencilEnabled)
    {
        [[FTPenManager sharedInstance] update];
    }
}

- (CGPoint)glPointFromEvent:(UIEvent*)event
{
    CGRect   bounds = [self.view bounds];
    UITouch*    touch = [[event touchesForView:self.view] anyObject];
    // Convert touch point from UIView referential to OpenGL one (upside-down flip)
    CGPoint location = [touch locationInView:self.view];
    location.y = bounds.size.height - location.y;
    return location;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [_pointsToRender removeAllObjects];
    [_pointsToRender addObject:[NSValue valueWithCGPoint:[self glPointFromEvent:event]]];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    [_pointsToRender addObject:[NSValue valueWithCGPoint:[self glPointFromEvent:event]]];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [_pointsToRender addObject:[NSValue valueWithCGPoint:[self glPointFromEvent:event]]];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    
}

#pragma mark - GLKView delegate
- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    
    glClearColor(0.65f, 0.65f, 0.65f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glUseProgram(_program);
    
    // Render a poly line.
    if ([_pointsToRender count] >= 2)
    {
        for(NSInteger i = 0; i < [_pointsToRender count]-1; ++i)
        {
            [self renderLineFromPoint:[(NSValue*)_pointsToRender[i] CGPointValue]
                              toPoint:[(NSValue*)_pointsToRender[i+1] CGPointValue]];
        }
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
    if(vertexBuffer == NULL)
    {
        vertexBuffer = malloc(vertexMax * 2 * sizeof(GLfloat));
    }
    
    // Add points to the buffer so there are drawing points every X pixels
    count = MAX(ceilf(sqrtf((end.x - start.x) * (end.x - start.x) + (end.y - start.y) * (end.y - start.y)) / kBrushPixelStep), 1);
    for(i = 0; i < count; ++i)
    {
        if(vertexCount == vertexMax)
        {
            vertexMax = 2 * vertexMax;
            vertexBuffer = realloc(vertexBuffer, vertexMax * 2 * sizeof(GLfloat));
        }
        
        vertexBuffer[2 * vertexCount + 0] = start.x + (end.x - start.x) * ((GLfloat)i / (GLfloat)count);
        vertexBuffer[2 * vertexCount + 1] = start.y + (end.y - start.y) * ((GLfloat)i / (GLfloat)count);
        vertexCount += 1;
    }
    
    // Load data to the Vertex Buffer Object
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, vertexCount*2*sizeof(GLfloat), vertexBuffer, GL_DYNAMIC_DRAW);
    
    glEnableVertexAttribArray(ATTRIB_VERTEX);
    glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, GL_FALSE, 0, 0);
    
    // We don't need the use program as there's only ever 1 shader in use.
    glUseProgram(_program);
    
    glDrawArrays(GL_POINTS, 0, vertexCount);
}


#pragma mark - OpenGL ES shader state changes
- (void)setBrushColorWithRed:(CGFloat)red
                       green:(CGFloat)green
                        blue:(CGFloat)blue
{
    // Update the brush color
    GLfloat brushColor[4];
    brushColor[0] = red * kBrushOpacity;
    brushColor[1] = green * kBrushOpacity;
    brushColor[2] = blue * kBrushOpacity;
    brushColor[3] = kBrushOpacity;
    
    glUseProgram(_program);
    glUniform4fv(uniforms[UNIFORM_VERTEX_COLOR], 1, brushColor);
}
- (void)setPointSize
{
    glUseProgram(_program);
    glUniform1f(uniforms[UNIFORM_POINT_SIZE], 8.0f);
}
- (void)updateViewportAndTransforms
{
    // TODO what is up with GLKView's w/h
    _backingWidth = self.view.frame.size.height * self.view.contentScaleFactor;
    _backingHeight = self.view.frame.size.width * self.view.contentScaleFactor;
    
    // Update projection matrix , the model is the identity.
    GLKMatrix4 projectionMatrix = GLKMatrix4MakeOrtho(0, _backingWidth, 0, _backingHeight, -1, 1);
    
    glUseProgram(_program);
    glUniformMatrix4fv(uniforms[UNIFORM_MVP], 1, GL_FALSE, projectionMatrix.m);
    
    // Update viewport
    glViewport(0, 0, _backingWidth, _backingHeight);
}

#pragma mark -  OpenGL ES 2 shader compilation

- (BOOL)loadShaders
{
    GLuint vertShader, fragShader;
    NSString *vertShaderPathname, *fragShaderPathname;

    // Create shader program.
    _program = glCreateProgram();

    // Create and compile vertex shader.
    vertShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vsh"];
    if (![self compileShader:&vertShader type:GL_VERTEX_SHADER file:vertShaderPathname]) {
        NSLog(@"Failed to compile vertex shader");
        return NO;
    }

    // Create and compile fragment shader.
    fragShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"fsh"];
    if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER file:fragShaderPathname]) {
        NSLog(@"Failed to compile fragment shader");
        return NO;
    }

    // Attach vertex shader to program.
    glAttachShader(_program, vertShader);

    // Attach fragment shader to program.
    glAttachShader(_program, fragShader);

    // Bind attribute locations.
    // This needs to be done prior to linking.
    for(int i = 0; i < NUM_ATTRIBS; ++i)
    {
        glBindAttribLocation(_program, attributes[i], attribName[i]);
    }
   
    // Link program.
    if (![self linkProgram:_program]) {
        NSLog(@"Failed to link program: %d", _program);

        if (vertShader) {
            glDeleteShader(vertShader);
            vertShader = 0;
        }
        if (fragShader) {
            glDeleteShader(fragShader);
            fragShader = 0;
        }
        if (_program) {
            glDeleteProgram(_program);
            _program = 0;
        }

        return NO;
    }
    
    // Get uniform locations.
    for(int i = 0; i < NUM_UNIFORMS; ++i)
    {
        uniforms[i] = glGetUniformLocation(_program, uniformName[i]);
    }

    // Release vertex and fragment shaders.
    if (vertShader) {
        glDetachShader(_program, vertShader);
        glDeleteShader(vertShader);
    }
    if (fragShader) {
        glDetachShader(_program, fragShader);
        glDeleteShader(fragShader);
    }

    return YES;
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file
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

- (BOOL)linkProgram:(GLuint)prog
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

- (BOOL)validateProgram:(GLuint)prog
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

@end
