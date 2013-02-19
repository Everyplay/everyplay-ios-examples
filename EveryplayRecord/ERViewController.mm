/*
 * Copyright 2013 Applifier
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

#import "ERViewController.h"

#if USE_AUDIO
#import "fmod.hpp"
#import "fmod_errors.h"
#import "fmodiphone.h"

FMOD::System *fmod_system;
FMOD::Sound *sound1;
FMOD::Channel *channel;
#endif

// Uniform index.
enum {
    UNIFORM_TRANSLATE,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

// Attribute index.
enum {
    ATTRIB_VERTEX,
    ATTRIB_COLOR,
    NUM_ATTRIBUTES
};

@interface ERViewController ()
@property (nonatomic, strong) EAGLContext *context;
@property (nonatomic, unsafe_unretained) CADisplayLink *__unsafe_unretained displayLink;

@property (nonatomic, retain) IBOutlet UIButton *everyplayButton;
@property (nonatomic, retain) IBOutlet UIButton *recordButton;
@property (nonatomic, retain) IBOutlet UIButton *videoButton;
@property (nonatomic, retain) IBOutlet UIButton *loginButton;
@property (nonatomic, retain) IBOutlet UIButton *hudButton;
@property (nonatomic) BOOL hudEnabled;

- (BOOL)loadShaders;
- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file;
- (BOOL)linkProgram:(GLuint)prog;
- (BOOL)validateProgram:(GLuint)prog;
@end

@implementation ERViewController
@synthesize animating;
@synthesize context;
@synthesize displayLink;

@synthesize everyplayButton;
@synthesize recordButton;
@synthesize videoButton;
@synthesize loginButton;
@synthesize hudButton;
@synthesize hudEnabled;

- (void)dealloc
{
    if (program) {
        glDeleteProgram(program);
        program = 0;
    }

    // Tear down context.
    if ([EAGLContext currentContext] == context) {
        [EAGLContext setCurrentContext:nil];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [self startAnimation];

    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self stopAnimation];

    [super viewWillDisappear:animated];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    EAGLContext *aContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];

    if (!aContext) {
        aContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
    }

    if (!aContext) {
        NSLog(@"Failed to create ES context");
    } else if (![EAGLContext setCurrentContext:aContext]) {
        NSLog(@"Failed to set ES context current");
    }

    self.context = aContext;

    [(EAGLView *)self.view setContext:context];
    [(EAGLView *)self.view setFramebuffer];

    if ([context API] == kEAGLRenderingAPIOpenGLES2) {
        [self loadShaders];
    }

    animating = FALSE;
    animationFrameInterval = 1;
    self.displayLink = nil;

    // [Everyplay sharedInstance].flowControl = EveryplayFlowReturnsToVideoPlayer;

#if USE_AUDIO
    FMOD_RESULT   result        = FMOD_OK;
    char          buffer[200]   = {0};
    unsigned int  version       = 0;

    result = FMOD::Debug_SetLevel(FMOD_DEBUG_LEVEL_NONE);
    result = FMOD::System_Create(&fmod_system);
    result = fmod_system->getVersion(&version);

    if (version < FMOD_VERSION) {
        fprintf(stderr, "You are using an old version of FMOD %08x.  This program requires %08x\n", version, FMOD_VERSION);
        exit(-1);
    }

    result = fmod_system->setSoftwareFormat(44100, FMOD_SOUND_FORMAT_PCM16, 1, 0, FMOD_DSP_RESAMPLER_LINEAR);

    FMOD_IPHONE_EXTRADRIVERDATA extradriverdata;
    memset(&extradriverdata, 0, sizeof(FMOD_IPHONE_EXTRADRIVERDATA));
    extradriverdata.sessionCategory = FMOD_IPHONE_SESSIONCATEGORY_AMBIENTSOUND;
    extradriverdata.forceMixWithOthers = false;

    result = fmod_system->init(32, FMOD_INIT_NORMAL, &extradriverdata);

    [[NSString stringWithFormat:@"%@/loop.wav", [[NSBundle mainBundle] resourcePath]] getCString:buffer maxLength:200 encoding:NSASCIIStringEncoding];
    result = fmod_system->createSound(buffer, FMOD_SOFTWARE | FMOD_LOOP_NORMAL, NULL, &sound1);

    result = fmod_system->playSound(FMOD_CHANNEL_FREE, sound1, false, &channel);
#endif

    // Do any additional setup after loading the view, typically from a nib.
#if USE_EVERYPLAY
    [self createButtons];
#endif
}

- (void)viewDidUnload
{
    [super viewDidUnload];

    if (program) {
        glDeleteProgram(program);
        program = 0;
    }

    // Tear down context.
    if ([EAGLContext currentContext] == context) {
        [EAGLContext setCurrentContext:nil];
    }
    self.context = nil;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSInteger)animationFrameInterval
{
    return animationFrameInterval;
}

- (void)setAnimationFrameInterval:(NSInteger)frameInterval
{
    /*
     Frame interval defines how many display frames must pass between each time the display link fires.
     The display link will only fire 30 times a second when the frame internal is two on a display that refreshes 60 times a second. The default frame interval setting of one will fire 60 times a second when the display refreshes at 60 times a second. A frame interval setting of less than one results in undefined behavior.
     */
    if (frameInterval >= 1) {
        animationFrameInterval = frameInterval;

        if (animating) {
            [self stopAnimation];
            [self startAnimation];
        }
    }
}

- (void)startAnimation
{
    if (!animating) {
        CADisplayLink *aDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(drawFrame)];
        [aDisplayLink setFrameInterval:animationFrameInterval];
        [aDisplayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        self.displayLink = aDisplayLink;

        animating = TRUE;
    }
}

- (void)stopAnimation
{
    if (animating) {
        [self.displayLink invalidate];
        self.displayLink = nil;
        animating = FALSE;
    }
}

- (void)drawFrame
{
    [(EAGLView *)self.view setFramebuffer];

    // Replace the implementation of this method to do your own custom drawing.
    static const GLfloat squareVertices[] = {
        -0.5f, -0.33f,
        0.5f, -0.33f,
        -0.5f,  0.33f,
        0.5f,  0.33f,
    };


    static const GLubyte squareColors[] = {
        255, 255,   0, 255,
        0,   255, 255, 255,
        0,     0,   0,   0,
        255,   0, 255, 255,
    };

    static float transY = 0.0f;

    glClearColor(0.45f, 0.45f, 0.45f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    if ([context API] == kEAGLRenderingAPIOpenGLES2) {
        // Use shader program.
        glUseProgram(program);

        // Update uniform value.
        glUniform1f(uniforms[UNIFORM_TRANSLATE], (GLfloat)transY);
        transY += 0.075f;

        // Update attribute values.
        glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, 0, 0, squareVertices);
        glEnableVertexAttribArray(ATTRIB_VERTEX);
        glVertexAttribPointer(ATTRIB_COLOR, 4, GL_UNSIGNED_BYTE, 1, 0, squareColors);
        glEnableVertexAttribArray(ATTRIB_COLOR);

        // Validate program before drawing. This is a good check, but only really necessary in a debug build.
        // DEBUG macro must be defined in your debug configurations if that's not already the case.
#if DEBUG
        if (![self validateProgram:program]) {
            NSLog(@"Failed to validate program: %d", program);
            return;
        }
#endif
        // Render original demo
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

        if (self.hudEnabled == NO) {
#if USE_EVERYPLAY
            [[[Everyplay sharedInstance] capture] snapshotRenderbuffer];
#endif
        }

        glUniform1f(uniforms[UNIFORM_TRANSLATE], (GLfloat)transY + 3.1415926536f);
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    } else {
        glMatrixMode(GL_PROJECTION);
        glLoadIdentity();
        glMatrixMode(GL_MODELVIEW);
        glLoadIdentity();
        glTranslatef((GLfloat)(cosf(transY)*0.5f), (GLfloat)(sinf(transY)/2.0f), 0.0f);
        transY += 0.075f;

        glVertexPointer(2, GL_FLOAT, 0, squareVertices);
        glEnableClientState(GL_VERTEX_ARRAY);
        glColorPointer(4, GL_UNSIGNED_BYTE, 0, squareColors);
        glEnableClientState(GL_COLOR_ARRAY);

        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

        if (self.hudEnabled == NO) {
#if USE_EVERYPLAY
            [[[Everyplay sharedInstance] capture] snapshotRenderbuffer];
#endif
        }

        float transY2 = transY + 3.1415926536f;

        glLoadIdentity();
        glTranslatef((GLfloat)(cosf(transY2)*0.5f), (GLfloat)(sinf(transY2)/2.0f), 0.0f);

        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    }

    [(EAGLView *)self.view presentFramebuffer];
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file
{
    GLint status;
    const GLchar *source;

    source = (GLchar *)[[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil] UTF8String];
    if (!source) {
        NSLog(@"Failed to load vertex shader");
        return FALSE;
    }

    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);

#if DEBUG
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
        return FALSE;
    }

    return TRUE;
}

- (BOOL)linkProgram:(GLuint)prog
{
    GLint status;

    glLinkProgram(prog);

#if DEBUG
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
    if (status == 0)
        return FALSE;

    return TRUE;
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
    if (status == 0)
        return FALSE;

    return TRUE;
}

- (BOOL)loadShaders
{
    // Create shader program.
    program = glCreateProgram();

    // Create and compile vertex shader.
    NSString *vShaderFile = [[NSBundle mainBundle] pathForResource:@"Shader_v" ofType:@"glsl"];
    GLuint vShader = 0;
    if (![self compileShader:&vShader type:GL_VERTEX_SHADER file:vShaderFile]) {
        NSLog(@"Failed to compile vertex shader");
        return FALSE;
    }

    // Create and compile fragment shader.
    NSString *fShaderFile = [[NSBundle mainBundle] pathForResource:@"Shader_f" ofType:@"glsl"];
    GLuint fShader = 0;
    if (![self compileShader:&fShader type:GL_FRAGMENT_SHADER file:fShaderFile]) {
        NSLog(@"Failed to compile fragment shader");
        return FALSE;
    }

    // Attach vertex shader to program.
    glAttachShader(program, vShader);

    // Attach fragment shader to program.
    glAttachShader(program, fShader);

    // Bind attribute locations.
    // This needs to be done prior to linking.
    glBindAttribLocation(program, ATTRIB_VERTEX, "position");
    glBindAttribLocation(program, ATTRIB_COLOR, "color");

    // Link program.
    if (![self linkProgram:program]) {
        NSLog(@"Failed to link program: %d", program);
        
        if (vShader) {
            glDeleteShader(vShader);
            vShader = 0;
        }
        if (fShader) {
            glDeleteShader(fShader);
            fShader = 0;
        }
        if (program) {
            glDeleteProgram(program);
            program = 0;
        }
        
        return FALSE;
    }
    
    // Get uniform locations.
    uniforms[UNIFORM_TRANSLATE] = glGetUniformLocation(program, "translate");
    
    // Release vertex and fragment shaders.
    if (vShader) {
        glDeleteShader(vShader);
    }
    if (fShader) {
        glDeleteShader(fShader);
    }
    
    return TRUE;
}

#pragma mark - Rotation

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

- (NSUInteger) supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (BOOL) shouldAutorotate {
    return YES;
}

#pragma mark -

#if USE_EVERYPLAY

- (void)createButtons {
    int buttonX = 10;
    int buttonY = 10;
    int buttonWidth = 200;
    int buttonHeight = 40;
    int padding = 8;

    everyplayButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    everyplayButton.frame = CGRectMake(buttonX, buttonY, buttonWidth, buttonHeight);
    [everyplayButton setTitle: @"Everyplay" forState: UIControlStateNormal];
    [everyplayButton setTitleColor: [UIColor blackColor] forState: UIControlStateNormal];
    [everyplayButton setTitleColor: [UIColor yellowColor] forState: UIControlStateHighlighted];

    [everyplayButton addTarget:self action:@selector(everyplayButtonPressed:)
              forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview: everyplayButton];

    buttonY = buttonY + buttonHeight + padding;
    recordButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    recordButton.frame = CGRectMake(buttonX, buttonY, buttonWidth, buttonHeight);
    [recordButton setTitle: @"Start Recording" forState: UIControlStateNormal];
    [recordButton setTitleColor: [UIColor blackColor] forState: UIControlStateNormal];
    [recordButton setTitleColor: [UIColor yellowColor] forState: UIControlStateHighlighted];

    [recordButton addTarget:self action:@selector(recordButtonPressed:)
           forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview: recordButton];

    buttonY = buttonY + buttonHeight + padding;
    videoButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    videoButton.frame = CGRectMake(buttonX, buttonY, buttonWidth, buttonHeight);
    [videoButton setTitle: @"Test Video Playback" forState: UIControlStateNormal];
    [videoButton setTitleColor: [UIColor blackColor] forState: UIControlStateNormal];
    [videoButton setTitleColor: [UIColor yellowColor] forState: UIControlStateHighlighted];

    [videoButton addTarget:self action:@selector(videoButtonPressed:)
          forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview: videoButton];

    buttonY = buttonY + buttonHeight + padding;
    loginButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    loginButton.frame = CGRectMake(buttonX, buttonY, buttonWidth, buttonHeight);
    [loginButton setTitle: @"Login" forState: UIControlStateNormal];
    [loginButton setTitleColor: [UIColor blackColor] forState: UIControlStateNormal];
    [loginButton setTitleColor: [UIColor yellowColor] forState: UIControlStateHighlighted];

    [loginButton addTarget:self action:@selector(loginButtonPressed:)
          forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview: loginButton];
    [self updateLoginButtonState:loginButton];

    buttonY = buttonY + buttonHeight + padding;
    hudButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    hudButton.frame = CGRectMake(buttonX, buttonY, buttonWidth, buttonHeight);
    [hudButton setTitle: @"HUD record off" forState: UIControlStateNormal];
    [hudButton setTitleColor: [UIColor blackColor] forState: UIControlStateNormal];
    [hudButton setTitleColor: [UIColor yellowColor] forState: UIControlStateHighlighted];

    [hudButton addTarget:self action:@selector(hudButtonPressed:)
          forControlEvents:UIControlEventTouchUpInside];

    hudButton.hidden = YES;
    self.hudEnabled = YES;

    [self.view addSubview: hudButton];
}

- (IBAction)everyplayButtonPressed:(id)sender {
    [[Everyplay sharedInstance] showEveryplay];
}

- (IBAction)recordButtonPressed:(id)sender {
    if ([[[Everyplay sharedInstance] capture] isRecording]) {
        [[[Everyplay sharedInstance] capture] stopRecording];
    } else {
        [[[Everyplay sharedInstance] capture] startRecording];
    }
}

- (IBAction)videoButtonPressed:(id)sender {
    UIButton *button = (UIButton *)sender;

    if ([button.titleLabel.text isEqualToString:@"Test Video Playback"] == YES) {
        NSURL *testUrl = [[NSURL alloc] initWithString:@"https://api.everyplay.com/videos?order=popularity&limit=1"];

        [[Everyplay sharedInstance] playVideoWithURL:testUrl];
    } else {
        [[Everyplay sharedInstance] playLastRecording];
    }
}

- (void)updateLoginButtonState:(id)sender {
    EveryplayAccount *account = [Everyplay account];

    if (account == nil) {
        [sender setTitle:@"Login" forState:UIControlStateNormal];
    } else {
        [account loadUserWithCompletionHandler:^(NSError *err, NSDictionary *user) {
            EveryplayLog(@"already logged in");
        }];
        [sender setTitle:@"Logout" forState:UIControlStateNormal];
    }
}

- (IBAction)loginButtonPressed:(id)sender {
    EveryplayAccount *account = [Everyplay account];

    if (account == nil) {
        [Everyplay requestAccessforScopes:@"" withCompletionHandler:^(NSError *err) {
            if (EVERYPLAY_CANCELED(err)) {
                EveryplayLog(@"Canceled!");
            } else if (err) {
                EveryplayLog(@"Error: %@", [err localizedDescription]);
            } else {
                EveryplayLog(@"Logged in as:");
                [[Everyplay account] loadUserWithCompletionHandler:^(NSError *err, NSDictionary *user) {
                    EveryplayLog(@"%@",user);
                }];
            }
            [self updateLoginButtonState:sender];
        }];
    } else {
        [Everyplay removeAccess];
        [self updateLoginButtonState:sender];
    }
}

- (IBAction)hudButtonPressed:(id)sender {
    if (self.hudEnabled) {
        [hudButton setTitle:@"HUD record on" forState:UIControlStateNormal];
        self.hudEnabled = NO;
    } else {
        [hudButton setTitle:@"HUD record off" forState:UIControlStateNormal];
        self.hudEnabled = YES;
    }
}

#pragma mark - Delegate Methods
- (void)everyplayShown {
    ELOG;

    [self stopAnimation];
#if USE_AUDIO
    channel->setMute(true);
#endif
}

- (void)everyplayHidden {
    ELOG;

    [self startAnimation];
#if USE_AUDIO
    channel->setMute(false);
#endif
}

- (void)everyplayRecordingStarted {
    ELOG;

    hudButton.hidden = NO;
    [recordButton setTitle:@"Stop Recording" forState:UIControlStateNormal];
}

- (void)everyplayRecordingStopped {
    ELOG;

    hudButton.hidden = YES;
    [recordButton setTitle:@"Start Recording" forState:UIControlStateNormal];
    [videoButton setTitle: @"Play Last Recording" forState: UIControlStateNormal];

    [[Everyplay sharedInstance] mergeSessionDeveloperData:@{@"testString" : @"hello"}];
    [[Everyplay sharedInstance] mergeSessionDeveloperData:@{@"testInteger" : @42}];
}

#endif

@end
