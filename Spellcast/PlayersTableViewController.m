//
//  PlayersTableViewController.m
//  Spellcast
//
//  Created by ch484-mac7 on 4/28/15.
//  Copyright (c) 2015 SMUJSJ. All rights reserved.
//

#import "PlayersTableViewController.h"
#import "DuelViewController.h"

@interface PlayersTableViewController ()

@property (strong, nonatomic) NSMutableArray* nearbyPlayers;
@property (strong, nonatomic) MatchModel* matchModel;

@end

@implementation PlayersTableViewController

// Lazy instantiation
- (NSMutableArray*)nearbyPlayers {
    if (!_nearbyPlayers) {
        _nearbyPlayers = [[NSMutableArray alloc] init];
    }
    return _nearbyPlayers;
}

// Gets an instance of the MatchModel class using lazy instantiation
- (MatchModel*) matchModel {
    if(!_matchModel)
        _matchModel = [MatchModel sharedInstance];
    
    return _matchModel;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    NSLog(@"viewWillAppear");
    
    [self.matchModel updateWithViewController:self];
    
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
            [[GKMatchmaker sharedMatchmaker] finishMatchmakingForMatch:self.matchModel.match];
        }
    };
    
    void (^matchCreateCompletionHandler)(GKMatch*, NSError*) = ^(GKMatch *match, NSError *error) {
        if (error) {
            NSLog(@"Error creating match: %@", [error description]);
            
            [[GKMatchmaker sharedMatchmaker] cancelPendingInviteToPlayer:player];
            
        }
        else {
            
            //We have a new match object.
            [self.matchModel updateWithMatch:match viewController:self];
            
        }
    };
    
    void (^matchAddCompletionHandler)(NSError*) = ^(NSError *error) {
        matchCreateCompletionHandler(self.matchModel.match, error);
    };
    
    if (!self.matchModel.match) {
        [[GKMatchmaker sharedMatchmaker] findMatchForRequest:request withCompletionHandler:matchCreateCompletionHandler];
    }
    else {
        [[GKMatchmaker sharedMatchmaker] addPlayersToMatch:self.matchModel.match matchRequest:request completionHandler:matchAddCompletionHandler];
    }
}

-(void)startDuel {
    NSLog(@"Starting duel...");
    [self performSegueWithIdentifier:@"DuelSegue" sender:self];
    
}

#pragma mark GKMatchDelegate methods
- (void)match:(GKMatch *)match didFailWithError:(NSError *)error {
    NSLog(@"MATCH FAILED: %@", [error description]);
    
}

- (void)match:(GKMatch *)match
       player:(GKPlayer *)player
didChangeConnectionState:(GKPlayerConnectionState)state {
    
    NSLog(@"PLAYER CHANGED STATE: %@", [self.matchModel nameForPlayerState:state]);
    NSLog(@"Change Players: %@", self.matchModel.match.players);
    
    if (![self.matchModel isMatchRunning]) {
    //if (match.players.count == 0) {
        NSLog(@"hi");
        [self.matchModel endMatch];
    } else {
        [[GKMatchmaker sharedMatchmaker] finishMatchmakingForMatch:match];
        [self.matchModel sendMessage:@{@"command":@"start"} toPlayersInMatch:self.matchModel.match.players];
    }
}

-(void)match:(GKMatch *)match didReceiveData:(NSData *)data fromRemotePlayer:(GKPlayer *)player {
    NSDictionary* message = (NSDictionary*)[NSKeyedUnarchiver unarchiveObjectWithData:data];
    //NSString* message = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"Received '%@' from %@", message, player.displayName);
    
    if ([[message objectForKey:@"command"] isEqualToString:@"start"]) {
        [self startDuel];
    }
}


#pragma mark GKInviteEventListenerProtocol methods
- (void)player:(GKPlayer *)player didRequestMatchWithRecipients:(NSArray *)recipientPlayers {
    
}

- (void)player:(GKPlayer *)player didAcceptInvite:(GKInvite *)invite {
    
    [[GKMatchmaker sharedMatchmaker] matchForInvite:invite completionHandler:^(GKMatch *match, NSError *error) {
        
        NSLog(@"didAcceptInvite");
        if (error) {
            NSLog(@"Error creating match from invitation: %@", [error description]);
            //Tell ViewController that match connect failed.
            
        }
        else {
            
            [self.matchModel updateWithMatch:match viewController:self];
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
