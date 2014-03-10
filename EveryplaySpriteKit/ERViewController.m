/*
 * Copyright 2014 Applifier
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
#import "ERMyScene.h"

@implementation ERViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

#if USE_EVERYPLAY
    // Initialize Everyplay SDK with our client id and secret.
    // These can be created at https://developers.everyplay.com
    [Everyplay setClientId:@"b459897317dc88c80b4515e380e1378022f874d2" clientSecret:@"f1a162969efb1c27aac6977f35b34127e68ee163" redirectURI:@"https://m.everyplay.com/auth"];

    // Tell Everyplay to use our rootViewController for presenting views and for delegate calls.
    [Everyplay initWithDelegate:self andParentViewController:self];
#endif

    // Configure the view.
    SKView * skView = (SKView *)self.view;
    skView.showsFPS = YES;
    skView.showsNodeCount = YES;
    
    // Create and configure the scene.
    SKScene * scene = [ERMyScene sceneWithSize:skView.bounds.size];
    scene.scaleMode = SKSceneScaleModeAspectFill;
    
    // Present the scene.
    [skView presentScene:scene];
}

- (BOOL)shouldAutorotate
{
#if USE_EVERYPLAY
    if ([[[Everyplay sharedInstance] capture] isRecording] == YES) {
        return NO;
    }
#endif
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return UIInterfaceOrientationMaskAllButUpsideDown;
    } else {
        return UIInterfaceOrientationMaskAll;
    }
}

/* While recording, keep orientation locked */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
#if USE_EVERYPLAY
    if ([[[Everyplay sharedInstance] capture] isRecording] == YES) {
        return [UIApplication sharedApplication].statusBarOrientation == toInterfaceOrientation;
    }
#endif
    return [super shouldAutorotateToInterfaceOrientation:toInterfaceOrientation];
}

#if USE_EVERYPLAY
- (void)everyplayShown
{
    SKView *skView = (SKView *)self.view;
    skView.paused = YES;
}

- (void)everyplayHidden
{
    SKView *skView = (SKView *)self.view;
    skView.paused = NO;
}

- (void)everyplayRecordingStarted
{
    NSLog(@"everyplayRecordingStarted");
}

- (void)everyplayRecordingStopped
{
    NSLog(@"everyplayRecordingStopped");
}
#endif

- (IBAction)recordButton:(id)sender {
#if USE_EVERYPLAY
    BOOL isRecording = [[[Everyplay sharedInstance] capture] isRecording];

    if (isRecording == NO) {
        [[[Everyplay sharedInstance] capture] startRecording];
        [sender setTitle:@"Stop Recording" forState:UIControlStateNormal];
    } else {
        [[[Everyplay sharedInstance] capture] stopRecording];
        [[Everyplay sharedInstance] playLastRecording];
        [sender setTitle:@"Start Recording" forState:UIControlStateNormal];
    }
#else
    NSLog(@"Everyplay not enabled");
#endif
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

@end
