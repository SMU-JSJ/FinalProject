//
//  SpellModel.h
//  Assignment6
//
//  Created by ch484-mac7 on 4/12/15.
//  Copyright (c) 2015 SMUJSJ. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Spell.h"

@interface SpellModel : NSObject

+ (SpellModel*) sharedInstance;

@property (strong, nonatomic) NSString* SERVER_URL;
@property (strong, nonatomic) NSNumber* dsid;

@property (strong, nonatomic) NSMutableArray* attackSpells;
@property (strong, nonatomic) NSMutableArray* healingSpells;
@property (strong, nonatomic) NSMutableArray* defenseSpells;

- (Spell*) getSpellWithName:(NSString*)spellName;

- (void)updateModel;
- (void)sendFeatureArray:(NSArray*)data withLabel:(NSString*)label;

@end
