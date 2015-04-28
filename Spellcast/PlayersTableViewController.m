//
//  PlayersTableViewController.m
//  Spellcast
//
//  Created by ch484-mac7 on 4/28/15.
//  Copyright (c) 2015 SMUJSJ. All rights reserved.
//

#import "PlayersTableViewController.h"
#import <GameKit/GameKit.h>

@interface PlayersTableViewController ()

@end

@implementation PlayersTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) authenticateLocalPlayer
{
    
    static BOOL gcAuthenticationCalled = NO;
    if (!gcAuthenticationCalled) {
        GKLocalPlayer *localPlayer = [GKLocalPlayer localPlayer];
        
        void (^authenticationHandler)(UIViewController*, NSError*) = ^(UIViewController *viewController, NSError *error) {
            NSLog(@"Authenticating with Game Center.");
            GKLocalPlayer *myLocalPlayer = [GKLocalPlayer localPlayer];
            if (viewController != nil)
            {
                NSLog(@"Not authenticated - storing view controller.");
                //self.authenticationController = viewController;
                //_gcStatusCtrlr.loginStatus.text = @"Not Logged In - Touch to Connect.";
            }
            else if ([myLocalPlayer isAuthenticated])
            {
                NSLog(@"Player is authenticated!");
                
                [localPlayer unregisterAllListeners];
                [localPlayer registerListener:self];
                
                //_gcStatusCtrlr.loginStatus.text = @"Game Center Connected.  Touch to search for players.";
                
            }
            else
            {
                //Authentication failed.
                //self.authenticationController = nil;
                if (error) {
                    NSLog([error description], nil);
                }
                //_gcStatusCtrlr.loginStatus.text = @"Login Failed - cancelled by user.";
            }
            
            
        };
        
        localPlayer.authenticateHandler = authenticationHandler;
        gcAuthenticationCalled = YES;
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
#warning Potentially incomplete method implementation.
    // Return the number of sections.
    return 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
#warning Incomplete method implementation.
    // Return the number of rows in the section.
    return 0;
}

/*
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:<#@"reuseIdentifier"#> forIndexPath:indexPath];
    
    // Configure the cell...
    
    return cell;
}
*/

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
