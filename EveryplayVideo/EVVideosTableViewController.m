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

#import "EVVideosTableViewController.h"

@interface EVVideosTableViewController ()

@end


@implementation EVVideosTableViewController

@synthesize videos;

- (void)everyplayShown
{
}

- (void)everyplayHidden
{
}

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        videos = [NSArray array];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSLog(@"Number of rows: %d",[videos count]);
    return [videos count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [[UITableViewCell alloc]
                             initWithStyle:UITableViewCellStyleSubtitle
                             reuseIdentifier:@"cell"];
    NSDictionary *video = [videos objectAtIndex:indexPath.row];
    cell.textLabel.text = [video valueForKey:@"title"];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ likes, %@ views", [video valueForKey:@"likes_count"], [video valueForKey:@"views"]];
    return cell;
}


/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"PlayVideo: %d",indexPath.row);
    [[Everyplay sharedInstance] playVideoWithDictionary:[videos objectAtIndex:indexPath.row]];
}

- (void)loadVideos {
    NSURL *resource = [NSURL URLWithString:@"https://api.everyplay.com/videos"];
    [EveryplayRequest performMethod:EveryplayRequestMethodGET
                         onResource:resource
                    usingParameters:@{@"order":@"popularity"}
                        withAccount:[Everyplay account]
             sendingProgressHandler:nil
                    responseHandler:^(NSURLResponse *response, NSData *responseData, NSError *error) {
        if(error == nil) {
            id parsed = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:&error];
            if(parsed == nil) {
                NSLog(@"Unable to parse request data");
            } else if([parsed isKindOfClass:[NSArray class]]) {
                [self setVideos:(NSArray*)parsed];
                NSLog(@"Videos loaded");
                [self.tableView reloadData];
            }
        }
    }];
}

@end
