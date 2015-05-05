//
//  MatchModel.h
//  Spellcast
//
//  Created by ch484-mac7 on 5/5/15.
//  Copyright (c) 2015 SMUJSJ. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GameKit/GameKit.h>

@interface MatchModel : NSObject

+ (MatchModel*) sharedInstance;

@property (strong, nonatomic) GKMatch* match;

-(void)updateWithMatch:(GKMatch*)match viewController:(id<GKMatchDelegate>)viewController;
-(void)updateWithMatch:(GKMatch*)match;
-(void)updateWithViewController:(id<GKMatchDelegate>)viewController;
-(void)endMatch;
-(void)sendMessage:(NSDictionary*)message toPlayersInMatch:(NSArray*)players;
-(NSString*)nameForPlayerState:(GKPlayerConnectionState)state;
-(BOOL)isMatchRunning;

@end
