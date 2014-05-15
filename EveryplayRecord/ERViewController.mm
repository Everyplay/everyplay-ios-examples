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
#if USE_FMOD
#import "fmod.hpp"
#import "fmod_errors.h"
#import "fmodiphone.h"

FMOD::System *fmod_system;
FMOD::Sound *sound1;
FMOD::Channel *channel;
#endif
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
@property (nonatomic, retain) IBOutlet UIButton *modalButton;
@property (nonatomic, retain) IBOutlet UIButton *hudButton;
@property (nonatomic, retain) IBOutlet UIButton *faceCamButton;
@property (nonatomic) BOOL hudEnabled;

@property (nonatomic, retain) IBOutlet UIButton *play1Button;
@property (nonatomic, retain) IBOutlet UIButton *unload1Button;
@property (nonatomic, retain) IBOutlet UIButton *play2Button;
@property (nonatomic, retain) IBOutlet UIButton *unload2Button;
@property (nonatomic, retain) IBOutlet UIButton *pauseButton;
@property (nonatomic, retain) IBOutlet UIButton *resumeButton;
@property (nonatomic, retain) IBOutlet UIButton *rewindButton;
@property (nonatomic, retain) IBOutlet UIButton *stopButton;

@property (nonatomic, retain) IBOutlet UIButton *effect1Button;
@property (nonatomic, retain) IBOutlet UIButton *effect2Button;

@property (nonatomic) NSString *song1;
@property (nonatomic) NSString *song2;

@property (nonatomic) NSString *effect1;
@property (nonatomic) float effect1Pitch;
@property (nonatomic) NSString *effect2;
@property (nonatomic) float effect2Pitch;

- (BOOL)loadShaders;
- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file;
- (BOOL)linkProgram:(GLuint)prog;
- (BOOL)validateProgram:(GLuint)prog;
@end

@implementation ERViewController
@synthesize animating;
@synthesize context;
@synthesize displayLink;

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

    if ([context API] >= kEAGLRenderingAPIOpenGLES2) {
        [self loadShaders];
    }

    recordingPermissionGranted = NO;
    animating = FALSE;
    animationFrameInterval = 1;
    self.displayLink = nil;

    // [Everyplay sharedInstance].flowControl = EveryplayFlowReturnsToVideoPlayer;

    _song1 = [NSString stringWithFormat:@"%@/loop.wav", [[NSBundle mainBundle] resourcePath]];
    _song2 = [NSString stringWithFormat:@"%@/loop2.wav", [[NSBundle mainBundle] resourcePath]];

    _effect1 = [NSString stringWithFormat:@"%@/Pew.caf", [[NSBundle mainBundle] resourcePath]];
    _effect2 = [NSString stringWithFormat:@"%@/Pow.caf", [[NSBundle mainBundle] resourcePath]];

    _effect1Pitch = 1.0f;
    _effect2Pitch = 1.0f;

    self.hudEnabled = YES;

#if USE_AUDIO
#if USE_FMOD
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

    [_song1 getCString:buffer maxLength:200 encoding:NSASCIIStringEncoding];
    result = fmod_system->createSound(buffer, FMOD_SOFTWARE | FMOD_LOOP_NORMAL, NULL, &sound1);

    result = fmod_system->playSound(FMOD_CHANNEL_FREE, sound1, false, &channel);
#endif
#endif

    // Do any additional setup after loading the view, typically from a nib.
#if USE_EVERYPLAY
    [self createButtons];
#endif

    [self startAnimation];
}

- (void)viewDidUnload
{
    [self stopAnimation];

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

    if ([context API] >= kEAGLRenderingAPIOpenGLES2) {
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

#define ADD_BUTTON(x, title, selector) \
  x = [UIButton buttonWithType:UIButtonTypeRoundedRect]; \
  x.frame = CGRectMake(buttonX, buttonY, buttonWidth, buttonHeight); \
  [x setTitle:title forState: UIControlStateNormal]; \
  [x setTitleColor:[UIColor blackColor] forState:UIControlStateNormal]; \
  [x setTitleColor:[UIColor yellowColor] forState:UIControlStateHighlighted]; \
  [x addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside]; \
  [self.view addSubview:x];

- (void)createButtons {
    int buttonX = 10;
    int buttonY = 10;
    int buttonWidth = 200;
    int buttonHeight = 40;
    int padding = 8;

#if !USE_EVERYPLAY_AUDIO_BOARD
    ADD_BUTTON(_everyplayButton, @"Everyplay", @selector(everyplayButtonPressed:));

    buttonY = buttonY + buttonHeight + padding;
    ADD_BUTTON(_recordButton, @"Start recording", @selector(recordButtonPressed:));

    buttonY = buttonY + buttonHeight + padding;
    ADD_BUTTON(_videoButton, @"Test Video Playback", @selector(videoButtonPressed:));

    buttonY = buttonY + buttonHeight + padding;
    ADD_BUTTON(_modalButton, @"Show sharing modal", @selector(modalButtonPressed:));

    buttonY = buttonY + buttonHeight + padding;
    ADD_BUTTON(_loginButton, @"Login", @selector(loginButtonPressed:));
    [self updateLoginButtonState:_loginButton];

    buttonY = buttonY + buttonHeight + padding;
    ADD_BUTTON(_hudButton, @"HUD record off", @selector(hudButtonPressed:));
    _hudButton.hidden = NO;

    buttonY = buttonY + buttonHeight + padding;
    ADD_BUTTON(_faceCamButton, @"Request REC permission", @selector(faceCamButtonPressed:));
#else
    ADD_BUTTON(_play1Button, @"Play song #1", @selector(play1ButtonPressed:));

    buttonY = buttonY + buttonHeight + padding;
    ADD_BUTTON(_unload1Button, @"Unload song #1", @selector(unload1ButtonPressed:));

    buttonY = buttonY + buttonHeight + padding;
    ADD_BUTTON(_pauseButton, @"Pause song", @selector(pauseButtonPressed:));

    buttonY = buttonY + buttonHeight + padding;
    ADD_BUTTON(_resumeButton, @"Resume song", @selector(resumeButtonPressed:));

    buttonY = buttonY + buttonHeight + padding;
    ADD_BUTTON(_rewindButton, @"Rewind song", @selector(rewindButtonPressed:));

    buttonY = buttonY + buttonHeight + padding;
    ADD_BUTTON(_stopButton, @"Stop song", @selector(stopButtonPressed:));

    buttonY = 10;
    buttonX = buttonX + buttonWidth + padding;

    ADD_BUTTON(_play2Button, @"Play song #2", @selector(play2ButtonPressed:));

    buttonY = buttonY + buttonHeight + padding;
    ADD_BUTTON(_unload2Button, @"Unload song #2", @selector(unload2ButtonPressed:));

    buttonY = buttonY + buttonHeight + padding;
    ADD_BUTTON(_effect1Button, @"Effect #1", @selector(effect1ButtonPressed:));

    buttonY = buttonY + buttonHeight + padding;
    ADD_BUTTON(_effect2Button, @"Effect #2", @selector(effect2ButtonPressed:));

    buttonY = buttonY + buttonHeight + padding;
    ADD_BUTTON(_recordButton, @"Start recording", @selector(recordButtonPressed:));

    buttonY = buttonY + buttonHeight + padding;
    ADD_BUTTON(_videoButton, @"Test Video Playback", @selector(videoButtonPressed:));
#endif
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

- (IBAction)modalButtonPressed:(id)sender {
    [[Everyplay sharedInstance] showEveryplaySharingModal];
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
        [_hudButton setTitle:@"HUD record on" forState:UIControlStateNormal];
        self.hudEnabled = NO;
    } else {
        [_hudButton setTitle:@"HUD record off" forState:UIControlStateNormal];
        self.hudEnabled = YES;
    }
}

- (IBAction)faceCamButtonPressed:(id)sender {
    EveryplayFaceCam *faceCam = [[Everyplay sharedInstance] faceCam];

    if (faceCam) {
        if (faceCam.isSessionRunning == NO) {
            if(recordingPermissionGranted) {
                [faceCam setPreviewOrigin: EVERYPLAY_FACECAM_PREVIEW_ORIGIN_BOTTOM_RIGHT];
                [faceCam setPreviewPositionX: 16];
                [faceCam setPreviewPositionY: 16];
                [faceCam setPreviewBorderWidth: 4.0f];
                [faceCam setPreviewSideWidth: 128.0f];
                [faceCam setPreviewScaleRetina: YES];

                EveryplayFaceCamColor color;
                color.r = 1;
                color.g = 0.3;
                color.b = 1;

                [faceCam setPreviewBorderColor:color];

                // [faceCam setPreviewVisible: NO];
                // [faceCam setAudioOnly: YES];

                [faceCam startSession];
            }
            else {
                [faceCam requestRecordingPermission];
            }
        } else {
            [faceCam stopSession];
        }
    }
}

#pragma mark - Audio testing

- (void)play1ButtonPressed:(id)sender {
    [[EveryplaySoundEngine sharedInstance] playBackgroundMusic:_song1 loop:YES];
}

- (void)unload1ButtonPressed:(id)sender {
    [[EveryplaySoundEngine sharedInstance] unloadBackgroundMusic:_song1];
}

- (void)play2ButtonPressed:(id)sender {
    [[EveryplaySoundEngine sharedInstance] playBackgroundMusic:_song2 loop:YES];
}

- (void)unload2ButtonPressed:(id)sender {
    [[EveryplaySoundEngine sharedInstance] unloadBackgroundMusic:_song2];
}

- (void)pauseButtonPressed:(id)sender {
    [[EveryplaySoundEngine sharedInstance] pauseBackgroundMusic];
}

- (void)resumeButtonPressed:(id)sender {
    [[EveryplaySoundEngine sharedInstance] resumeBackgroundMusic];
}

- (void)rewindButtonPressed:(id)sender {
    [[EveryplaySoundEngine sharedInstance] rewindBackgroundMusic];
}

- (void)stopButtonPressed:(id)sender {
    [[EveryplaySoundEngine sharedInstance] stopBackgroundMusic];
}

- (void)effect1ButtonPressed:(id)sender {
    _effect1Pitch += 0.1f;
    if (_effect1Pitch >= 2.0) {
        _effect1Pitch = 0.2f;
    }

    [[EveryplaySoundEngine sharedInstance] playEffect:_effect1 loop:NO pitch:_effect1Pitch pan:0.0f gain:1.0f];
}

- (void)effect2ButtonPressed:(id)sender {
    _effect2Pitch += 0.1f;
    if (_effect2Pitch >= 2.0) {
        _effect2Pitch = 0.2f;
    }

    [[EveryplaySoundEngine sharedInstance] playEffect:_effect2 loop:NO pitch:_effect2Pitch pan:0.0f gain:1.0f];
}

#pragma mark - Delegate Methods

- (void)everyplayFaceCamRecordingPermission:(NSNumber *)granted {
    if(granted) {
        recordingPermissionGranted = [granted boolValue];

        if(recordingPermissionGranted) {
            [_faceCamButton setTitle: @"Start FaceCam session" forState:UIControlStateNormal];
        }
    }
}

- (void)everyplayShown {
    ELOG;

    [self stopAnimation];
#if USE_AUDIO
#if USE_FMOD
    channel->setMute(true);
#endif
    [[EveryplaySoundEngine sharedInstance] pauseBackgroundMusic];
#endif
}

- (void)everyplayHidden {
    ELOG;

    [self startAnimation];
#if USE_AUDIO
#if USE_FMOD
    channel->setMute(false);
#endif
    [[EveryplaySoundEngine sharedInstance] resumeBackgroundMusic];
#endif
}

- (void)everyplayRecordingStarted {
    ELOG;

    _hudButton.hidden = NO;
    [_recordButton setTitle:@"Stop Recording" forState:UIControlStateNormal];
}

- (void)everyplayRecordingStopped {
    ELOG;

    _hudButton.hidden = YES;
    [_recordButton setTitle:@"Start Recording" forState:UIControlStateNormal];
    [_videoButton setTitle: @"Play Last Recording" forState: UIControlStateNormal];

    [[Everyplay sharedInstance] mergeSessionDeveloperData:@{@"testString" : @"hello"}];
    [[Everyplay sharedInstance] mergeSessionDeveloperData:@{@"testInteger" : @42}];
}

- (void)everyplayFaceCamSessionStarted {
    ELOG;
    [_faceCamButton setTitle:@"Stop FaceCam session" forState:UIControlStateNormal];
}

- (void)everyplayFaceCamSessionStopped {
    ELOG;
    [_faceCamButton setTitle:@"Start FaceCam session" forState:UIControlStateNormal];
}

- (void)everyplayUploadDidStart:(NSNumber *)videoId {
    EveryplayLog(@"Upload started for video %@", videoId);
}

- (void)everyplayUploadDidProgress:(NSNumber *)videoId progress:(NSNumber *)progress {
    EveryplayLog(@"Upload progress for video %@ = %@%%", videoId, progress);
}

- (void)everyplayUploadDidComplete:(NSNumber *)videoId {
    EveryplayLog(@"Upload completed for video %@", videoId);
}

#endif

@end
