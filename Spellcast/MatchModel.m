//
//  MatchModel.m
//  Spellcast
//
//  Created by ch484-mac7 on 5/5/15.
//  Copyright (c) 2015 SMUJSJ. All rights reserved.
//

#import "MatchModel.h"

@implementation MatchModel

// Instantiates for the shared instance of the Match Model class
+ (MatchModel*)sharedInstance {
    static MatchModel* _sharedInstance = nil;
    
    static dispatch_once_t oncePredicate;
    
    dispatch_once(&oncePredicate,^{
        _sharedInstance = [[MatchModel alloc] init];
    });
    
    return _sharedInstance;
}

- (void)updateWithMatch:(GKMatch*)match viewController:(id<GKMatchDelegate>)viewController {
    self.match = match;
    self.match.delegate = viewController;
}

- (void)updateWithMatch:(GKMatch*)match {
    self.match = match;
}

- (void)updateWithViewController:(id<GKMatchDelegate>)viewController {
    self.match.delegate = viewController;
}

- (void)endMatch {
    [self.match disconnect];
    self.match = nil;
}

- (void)sendMessage:(NSDictionary*)message toPlayersInMatch:(NSArray*)players {
    NSError* err = nil;
    
    if (![self.match sendData:[NSKeyedArchiver archivedDataWithRootObject:message] toPlayers:players dataMode:GKMatchSendDataReliable error:&err]) {
        if (err != nil) {
            NSLog(@"ERROR: Could not send message (%@) to players (%@)", message, [players componentsJoinedByString:@","]);
        } else {
            NSLog(@"NULL ERROR: Could not send message (%@) to players (%@)", message, [players componentsJoinedByString:@","]);
        }
    } else {
        NSLog(@"DEBUG: Message (%@) sent to players (%@)", message, [players componentsJoinedByString:@","]);
    }
}

-(NSString*)nameForPlayerState:(GKPlayerConnectionState)state {
    
    switch (state) {
        case GKPlayerStateConnected:
            return @"GKPlayerStateConnected";
            break;
            
        case GKPlayerStateDisconnected:
            return @"GKPlayerStateDisconnected";
            break;
            
        case GKPlayerStateUnknown:
            return @"GKPlayerStateUnknown";
            break;
            
        default:
            break;
    }
}

-(BOOL)isMatchRunning {
    if (self.match != nil && [self.match.players count] > 0) {
        return true;
    } else {
        return false;
    }
}

@end
