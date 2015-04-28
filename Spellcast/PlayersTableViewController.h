//
//  PlayersTableViewController.h
//  Spellcast
//
//  Created by ch484-mac7 on 4/28/15.
//  Copyright (c) 2015 SMUJSJ. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GameKit/GameKit.h>

@interface PlayersTableViewController : UITableViewController <GKMatchDelegate, GKLocalPlayerListener>

@end
