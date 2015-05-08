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
@property (strong, nonatomic) UIAlertView* startingDuelAlert;
@property (strong, nonatomic) UIAlertView* inviteSentAlert;

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
    NSLog(@"viewWillDisappear");
    [super viewWillDisappear:animated];
    
    [self stopSearchingForNearbyPlayers];
    
    // Dismiss all alerts
    [self dismissStartingDuelPopup];
    [self dismissInvitePlayerPopup];
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
    [self.nearbyPlayers removeAllObjects];
    [self.tableView reloadData];
    
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
            [self showStartingDuelPopup];
            [[GKMatchmaker sharedMatchmaker] finishMatchmakingForMatch:self.matchModel.match];
        } else {
            NSLog(@"Declined invite with response: %ld", (long)response);
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

- (void)showInvitePlayerPopup:(NSString*)playerName {
    [self dismissInvitePlayerPopup];
    self.inviteSentAlert = [[UIAlertView alloc] initWithTitle:@"Invitation Sent"
                                                      message:[NSString stringWithFormat:@"An invite was sent to %@.", [self removeQuotes:playerName]]
                                                     delegate:self
                                            cancelButtonTitle:@"OK"
                                            otherButtonTitles:nil];
    [self.inviteSentAlert show];
}

- (void)dismissInvitePlayerPopup {
    NSLog(@"dismissInvitePlayerPopup");
    if (self.inviteSentAlert) [self.inviteSentAlert dismissWithClickedButtonIndex:0 animated:TRUE];
}

- (void)showStartingDuelPopup {
    [self dismissStartingDuelPopup];
    self.startingDuelAlert = [[UIAlertView alloc] initWithTitle:@"Starting duel..."
                                                      message:@"Get ready for the duel to start!"
                                                     delegate:self
                                            cancelButtonTitle:nil
                                            otherButtonTitles:nil];
    [self.startingDuelAlert show];
}

- (void)dismissStartingDuelPopup {
    NSLog(@"dismissStartingDuelPopup");
    if (self.startingDuelAlert) [self.startingDuelAlert dismissWithClickedButtonIndex:0 animated:TRUE];
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

//#pragma mark GKMatchmakerViewControllerDelegate methods
//- (void)matchmakerViewController:(GKMatchmakerViewController *)viewController didFailWithError:(NSError *)error {
//    NSLog(@"matchmakerViewController didFailWithError");
//}
//
//- (void)matchmakerViewController:(GKMatchmakerViewController *)viewController hostedPlayerDidAccept:(GKPlayer *)player {
//    NSLog(@"matchmakerViewController hostedPlayerDidAccept");
//}
//
//- (void)matchmakerViewControllerWasCancelled:(GKMatchmakerViewController *)viewController {
//    NSLog(@"matchmakerViewControllerWasCancelled");
//}
//
//- (void)matchmakerViewController:(GKMatchmakerViewController *)viewController didFindHostedPlayers:(NSArray *)players {
//    NSLog(@"matchmakerViewController didFindHostedPlayers");
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
            [self showStartingDuelPopup];
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
    cell.textLabel.text = [self removeQuotes:player.displayName];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    GKPlayer* player = [self.nearbyPlayers objectAtIndex:indexPath.row];
    NSLog(@"Reached row selection: Player %@", player.displayName);
    [self invitePlayer:player];
    [self showInvitePlayerPopup:player.displayName];
}

#pragma mark - Utility

- (NSString*)removeQuotes:(NSString*)str {
    if ([str length] > 2) {
        return [[str substringToIndex:[str length] - 1] substringFromIndex:2];
    }
    return @"";
}

@end
