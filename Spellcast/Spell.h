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
        strength:(NSNumber*) strength
            cost:(NSNumber*) cost;

// The Latin name of the spell
@property (strong, nonatomic) NSString* name;
// The English translation of the spell
@property (strong, nonatomic) NSString* translation;
// The description of the spell
@property (strong, nonatomic) NSString* desc;
// The maximum number of defense/healing/attack points the spell is worth
@property (strong, nonatomic) NSNumber* strength;
// The amount of magic points a spell costs
@property (strong, nonatomic) NSNumber* cost;


// Note: add attack/heal/defense points later (for final project)

@end
