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

#import "ELViewController.h"
#import "ELAppDelegate.h"

@interface ELViewController ()

@property (strong, nonatomic) IBOutlet UIButton *buttonLoginLogout;
@property (strong, nonatomic) IBOutlet UITextView *textNoteOrLink;

- (IBAction)buttonClickHandler:(id)sender;
- (void)updateView;

@end

@implementation ELViewController

@synthesize textNoteOrLink = _textNoteOrLink;
@synthesize buttonLoginLogout = _buttonLoginLogout;

#pragma Mark EveryplayDelegate

-(void)everyplayHidden {
    NSLog(@"Everyplay shown");
}

-(void)everyplayShown {
    NSLog(@"Everyplay hidden");    
}

- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    [self updateView];
    if([Everyplay account] != nil) {
        // Since we have an account load the info from server and put into textfield
        [[Everyplay account] loadUserWithCompletionHandler:^(NSError *error, NSDictionary *data) {
            [self.textNoteOrLink setText:[data description]];
        }];
    }
}

- (void)updateView {

    // Do we have an active account
    if([Everyplay account] != nil) {
        [self.buttonLoginLogout setTitle:@"Logout" forState:UIControlStateNormal];
    } else {
        [self.buttonLoginLogout setTitle:@"Login" forState:UIControlStateNormal];
    }

}
// handler for button click, logs sessions in or out
- (IBAction)buttonClickHandler:(id)sender {
    // get the app delegate so that we can access the session property
    if([Everyplay account] != nil) {
        [Everyplay removeAccess];
        [self.textNoteOrLink setText:@""];
        [self updateView];
    } else {
        // Request access
        [Everyplay requestAccessWithCompletionHandler:^(NSError *error) {
            if(error == nil) {
                // We are logged in
                EveryplayAccount *account = [Everyplay account];
                if(account != nil) {
                    // Load the player info from server
                    [account loadUserWithCompletionHandler:^(NSError *error, NSDictionary *data) {
                        // set the info the text field
                        [self.textNoteOrLink setText:[data description]];
                    }];
                }
            }
            [self updateView];
        }];
    }

}

#pragma mark Template generated code

- (void)viewDidUnload
{
    self.buttonLoginLogout = nil;
    self.textNoteOrLink = nil;
    
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    } else {
        return YES;
    }
}

#pragma mark -

@end
