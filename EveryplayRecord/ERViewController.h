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

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>
#import "EAGLView.h"
#import "Config.h"

#if USE_EVERYPLAY
#import <Everyplay/Everyplay.h>
#endif

// Conditional debug
#if DEBUG
#define EveryplayLog(fmt, ...) NSLog((@"[#%.3d] %s " fmt), __LINE__, __PRETTY_FUNCTION__, ## __VA_ARGS__)
#else
#define EveryplayLog(...)
#endif

#define ELOG EveryplayLog(@"")

#if USE_EVERYPLAY
#define EP_DELEGATE <EveryplayDelegate, AVAudioPlayerDelegate>
#else
#define EP_DELEGATE
#endif

@interface ERViewController : UIViewController EP_DELEGATE {
    EAGLContext *context;
    GLuint program;

    BOOL animating;
    NSInteger animationFrameInterval;
    CADisplayLink *__unsafe_unretained displayLink;

    NSTimer *timer;

    BOOL recordingPermissionGranted;
}

@property (readonly, nonatomic, getter=isAnimating) BOOL animating;
@property (nonatomic) NSInteger animationFrameInterval;

- (void)startAnimation;
- (void)stopAnimation;

@end
