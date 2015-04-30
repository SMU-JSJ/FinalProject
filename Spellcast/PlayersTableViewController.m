//
//  PlayersTableViewController.m
//  Spellcast
//
//  Created by ch484-mac7 on 4/28/15.
//  Copyright (c) 2015 SMUJSJ. All rights reserved.
//

#import "PlayersTableViewController.h"

@interface PlayersTableViewController ()

@property (strong, nonatomic) NSMutableArray* nearbyPlayers;
@property (strong, nonatomic) GKMatch* match;
@property (nonatomic) BOOL matchStarted;
@property (nonatomic) BOOL sentInitialResponse;

@end

@implementation PlayersTableViewController

// Lazy instantiation
- (NSMutableArray*)nearbyPlayers {
    if (!_nearbyPlayers) {
        _nearbyPlayers = [[NSMutableArray alloc] init];
    }
    return _nearbyPlayers;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (![[GKLocalPlayer localPlayer] isAuthenticated]) {
        [self authenticateLocalPlayerAndStartSearchingForNearbyPlayers];
    } else {
        [self startSearchingForNearbyPlayers];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self stopSearchingForNearbyPlayers];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) authenticateLocalPlayerAndStartSearchingForNearbyPlayers {
    static BOOL gcAuthenticationCalled = NO;
    if (!gcAuthenticationCalled) {
        GKLocalPlayer *localPlayer = [GKLocalPlayer localPlayer];
        
        void (^authenticationHandler)(UIViewController*, NSError*) = ^(UIViewController *viewController, NSError *error) {
            NSLog(@"Authenticating with Game Center.");
            GKLocalPlayer *myLocalPlayer = [GKLocalPlayer localPlayer];
            if (viewController != nil) {
                NSLog(@"Not authenticated - storing view controller.");
                //self.authenticationController = viewController;
            } else if ([myLocalPlayer isAuthenticated]) {
                NSLog(@"Player is authenticated!");
                
                //iOS8 - register as a listener
                [localPlayer unregisterAllListeners];
                [localPlayer registerListener:self];
                
                [self startSearchingForNearbyPlayers];
                
            } else {
                //Authentication failed.
                //self.authenticationController = nil;
                if (error) {
                    NSLog([error description], nil);
                }
            }
            
            
        };
        
        localPlayer.authenticateHandler = authenticationHandler;
        gcAuthenticationCalled = YES;
    }
}

- (void)startSearchingForNearbyPlayers {
    [[GKMatchmaker sharedMatchmaker] startBrowsingForNearbyPlayersWithHandler:^(GKPlayer *player, BOOL reachable) {
        
        if (reachable && ![self.nearbyPlayers containsObject:player]) {
            NSLog(@"Player %@ is reachable", player.displayName);
            
            [self.nearbyPlayers addObject:player];
        } else if (!reachable && [self.nearbyPlayers containsObject:player]){
            NSLog(@"Player %@ is not reachable", player.displayName);
            
            [self.nearbyPlayers removeObject:player];
        }
        
        [self.tableView reloadData];
    }];
}

- (void)stopSearchingForNearbyPlayers {
    [[GKMatchmaker sharedMatchmaker] stopBrowsingForNearbyPlayers];
}

- (void)invitePlayer:(GKPlayer*)player {
    // Initialize the match request - Just targeting iOS 6 for now...
    GKMatchRequest* request = [[GKMatchRequest alloc] init];
    request.minPlayers = 2;
    request.maxPlayers = 2;
    request.recipients = [NSArray arrayWithObject:player];
    request.inviteMessage = @"Let's play!";
    
    request.recipientResponseHandler = ^(GKPlayer *player, GKInviteRecipientResponse response) {
        if (response == GKInviteeResponseAccepted) {
            NSLog(@"Yo, they accepted the invite!");
            [[GKMatchmaker sharedMatchmaker] finishMatchmakingForMatch:self.match];
        }
    };
    
    
    [[GKMatchmaker sharedMatchmaker] findMatchForRequest:request withCompletionHandler:^(GKMatch* match, NSError *error) {
        if (error)
        {
            NSLog(@"ERROR: Error makeMatch: %@", [error description] );
            //[self disconnectMatch];
        }
        else if (match != nil)
        {
            // Record the new match and set me up as the delegate...
            self.match = match;
            self.match.delegate = self;
            // There will be no players until the players accept...
        }
    }];
    
    
    // This gets called when somebody accepts
//    request.inviteeResponseHandler = ^(NSString *playerID, GKInviteeResponse response)
//    {
//        if (response == GKInviteeResponseAccepted)
//        {
//            //NSLog(@"DEBUG: Player Accepted: %@", playerID);
//            // Tell the infrastructure we are don matching and will start using the match
//            [[GKMatchmaker sharedMatchmaker] finishMatchmakingForMatch:self.MM_gameCenterCurrentMatch];
//        }
//    };
}

//- (void)match:(GKMatch *)match player:(NSString *)playerID didChangeState:(GKPlayerConnectionState)state{
//    switch (state)
//    {
//        case GKPlayerStateConnected:
//            // Handle a new player connection.
//            break;
//        case GKPlayerStateDisconnected:
//            // A player just disconnected.
//            break;
//        case GKPlayerStateUnknown:
//            // Player state unknown
//            break;
//    }
//    
//    if (!self.matchStarted && match.expectedPlayerCount == 0)
//    {
//        self.matchStarted = YES;
//        // Handle initial match negotiation.
//        if (!self.sentInitialResponse)
//        {
//            self.sentInitialResponse = true;
//            // Send a hello log entry
//            [self sendMessage: @"Message from friend, 'Hello, thanks for accepting, you have connected with me'" toPlayersInMatch: [NSArray arrayWithObject:playerID]];
//        }
//    }
//}
//
//- (void) sendMessage:(NSString*)action toPlayersInMatch:(NSArray*) playerIds{
//    NSError* err = nil;
//    if (![self.match sendData:[action dataUsingEncoding:NSUTF8StringEncoding] toPlayers:playerIds dataMode:GKMatchSendDataReliable error:&err])
//    {
//        if (err != nil)
//        {
//            NSLog(@"ERROR: Could not send action to players (%@): %@ (%ld) - '%@'" ,[self.match.players componentsJoinedByString:@","],[err localizedDescription],(long)[err code], action);
//        }
//        else
//        {
//            NSLog(@"ERROR: Could not send action to players (%@): null error - '%@'",[self.match.players componentsJoinedByString:@","], action);
//        }
//    }
//    else
//    {
//        NSLog(@"DEBUG: Message sent to players (%@) - '%@'",[self.match.players componentsJoinedByString:@","], action);
//    }
//}
//
//- (void)match:(GKMatch *)match didReceiveData:(NSData *)data fromPlayer:(NSString *)playerID{
//    NSString* actionString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
//    // Send the initial response after we got the initial send from the
//    // invitee...
//    if (!self.sentInitialResponse)
//    {
//        self.sentInitialResponse = true;
//        // Send a hello log entry
//        [self sendMessage: @"Message from friend, 'Hello, thanks for inviting, you have connected with %@'" toPlayersInMatch: [NSArray arrayWithObject:playerID]];
//    }
//    // Execute the action we were sent...
//    NSLog(@"%@", actionString);
//}


#pragma mark GKInviteEventListenerProtocol methods
- (void)player:(GKPlayer *)player didRequestMatchWithRecipients:(NSArray *)recipientPlayers {
    
}

- (void)player:(GKPlayer *)player didAcceptInvite:(GKInvite *)invite {
    
    [[GKMatchmaker sharedMatchmaker] matchForInvite:invite completionHandler:^(GKMatch *match, NSError *error) {
        
        if (error) {
            NSLog(@"Error creating match from invitation: %@", [error description]);
            //Tell ViewController that match connect failed.
            
        }
        else {
            
            //[self updateWithMatch:match];
            self.match = match;
            NSLog(@"Players: %@",self.match.players);
        }
    }];
    
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return [self.nearbyPlayers count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PlayerCell" forIndexPath:indexPath];
    
    GKPlayer* player = [self.nearbyPlayers objectAtIndex:indexPath.row];
    
    // Configure the cell...
    cell.textLabel.text = player.displayName;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    GKPlayer* player = [self.nearbyPlayers objectAtIndex:indexPath.row];
    NSLog(@"Reached row selection: Player %@", player.displayName);
    [self invitePlayer:player];
}

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
