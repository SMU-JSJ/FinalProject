//
//  Spell.h
//  Assignment6
//
//  Created by ch484-mac7 on 4/12/15.
//  Copyright (c) 2015 SMUJSJ. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Spell : NSObject

// Constructor/initializer for a spell
- (id) initSpell:(NSString*) name
     translation:(NSString*) translation
            desc:(NSString*) desc
            type:(int) type
        strength:(NSNumber*) strength
            cost:(NSNumber*) cost;

typedef enum spellTypeState {
    ATTACK,
    HEALMAGIC,
    HEALHEALTH,
    DEFEND
} SpellTypeState;

// The Latin name of the spell
@property (strong, nonatomic) NSString* name;
// The English translation of the spell
@property (strong, nonatomic) NSString* translation;
// The description of the spell
@property (strong, nonatomic) NSString* desc;
// The type of the spell
@property (nonatomic) SpellTypeState type;
// The maximum number of defense/healing/attack points the spell is worth
@property (strong, nonatomic) NSNumber* strength;
// The amount of magic points a spell costs
@property (strong, nonatomic) NSNumber* cost;



@end
