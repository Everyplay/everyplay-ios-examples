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

#import "ELAppDelegate.h"
#import "ELViewController.h"

@implementation ELAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        self.viewController = [[ELViewController alloc] initWithNibName:@"ELViewController_iPhone" bundle:nil];
    } else {
        self.viewController = [[ELViewController alloc] initWithNibName:@"ELViewController_iPad" bundle:nil];
    }
    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];

    // Initialize Everyplay SDK with our client id and secret.
    // These can be created at https://developers.everyplay.com
    [Everyplay setClientId:@"b459897317dc88c80b4515e380e1378022f874d2" clientSecret:@"f1a162969efb1c27aac6977f35b34127e68ee163" redirectURI:@"https://m.everyplay.com/auth"];

    // Tell Everyplay to use our rootViewController for presenting views and for delegate calls.
    [Everyplay initWithDelegate:self.viewController andParentViewController:self.window.rootViewController];

    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{

}

- (void)applicationDidEnterBackground:(UIApplication *)application
{

}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
  
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
   
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
