//
//  SpellModel.m
//  Assignment6
//
//  Created by ch484-mac7 on 4/12/15.
//  Copyright (c) 2015 SMUJSJ. All rights reserved.
//

#import "SpellModel.h"

@interface SpellModel () <NSURLSessionTaskDelegate>

// for the machine learning session
@property (strong,nonatomic) NSURLSession *session;

@end

@implementation SpellModel

// Instantiates for the shared instance of the Spell Model class
+ (SpellModel*)sharedInstance {
    static SpellModel* _sharedInstance = nil;
    
    static dispatch_once_t oncePredicate;
    
    dispatch_once(&oncePredicate,^{
        _sharedInstance = [[SpellModel alloc] init];
    });
    
    return _sharedInstance;
}

// Configure and create the NSURLSession if needed
- (NSURLSession*)session {
    if (!_session) {
        //setup NSURLSession (ephemeral)
        NSURLSessionConfiguration *sessionConfig =
        [NSURLSessionConfiguration ephemeralSessionConfiguration];
        
        sessionConfig.timeoutIntervalForRequest = 5.0;
        sessionConfig.timeoutIntervalForResource = 8.0;
        sessionConfig.HTTPMaximumConnectionsPerHost = 1;
        
        _session =
        [NSURLSession sessionWithConfiguration:sessionConfig
                                      delegate:self
                                 delegateQueue:nil];
    }
    return _session;
}

- (NSString*)SERVER_URL {
    if (!_SERVER_URL) {
        _SERVER_URL = @"http://jsj.floccul.us:8000";
    }
    return _SERVER_URL;
}

// Initializes the training data set ID
- (NSNumber*)dsid {
    if (!_dsid) {
        _dsid = @102;
    }
    return _dsid;
}

// Create the array of attack spells if needed, and populates with names,
// translations, and descriptions
- (NSMutableArray*)attackSpells {
    if(!_attackSpells) {
        _attackSpells = [[NSMutableArray alloc] init];
        
        NSArray* spellNames = @[@"Percutio Cum Fulmini", @"Creo Leonem"];
        NSArray* spellTranslations = @[@"Lightning Strike", @"Conjure Lion"];
        NSArray* spellDescriptions = @[@"Strikes a lightning bolt at the opponent.\n10 Attack, -10 Mana",
                                       @"Conjures a lion and attacks the opponent.\n20 Attack, -15 Mana"];
        NSArray* spellStrengths = @[@10, @20];
        NSArray* spellCosts = @[@10, @15];
        
        for (int i = 0; i < [spellNames count]; i++) {
            Spell* spell = [[Spell alloc] initSpell:spellNames[i]
                                        translation:spellTranslations[i]
                                               desc:spellDescriptions[i]
                                               type: ATTACK
                                           strength:spellStrengths[i]
                                               cost:spellCosts[i]];
            [self.attackSpells addObject:spell];
        }
    }
    
    return _attackSpells;
}

// Create the array of healing spells if needed, and populates with names,
// translations, and descriptions
- (NSMutableArray*)healingSpells {
    if(!_healingSpells) {
        _healingSpells = [[NSMutableArray alloc] init];
        
        NSArray* spellNames = @[@"Mentem Curro", @"Magicum Reddo", @"Corpum Sano"];
        NSArray* spellTranslations = @[@"Heal Mind",
                                       @"Restore Magic",
                                       @"Heal Body"];
        NSArray* spellDescriptions = @[@"Heals the user's mind.\n+5 HP, -5 Mana",
                                       @"Restores the user's spent magic.\n+10 Mana",
                                       @"Heals the user's body.\n+18 HP, -15 Mana"];
        NSArray* spellTypes = @[[NSNumber numberWithInt:HEALHEALTH],
                               [NSNumber numberWithInt:HEALMAGIC],
                               [NSNumber numberWithInt:HEALHEALTH]];
        NSArray* spellStrengths = @[@5, @11, @18];
        NSArray* spellCosts = @[@5, @1, @15];
        
        for (int i = 0; i < [spellNames count]; i++) {
            Spell* spell = [[Spell alloc] initSpell:spellNames[i]
                                        translation:spellTranslations[i]
                                               desc:spellDescriptions[i]
                                               type: [spellTypes[i] intValue]
                                           strength:spellStrengths[i]
                                               cost:spellCosts[i]];
            [self.healingSpells addObject:spell];
        }
    }
    
    return _healingSpells;
}

// Create the array of defense spells if needed, and populates with names,
// translations, and descriptions
- (NSMutableArray*)defenseSpells {
    if(!_defenseSpells) {
        _defenseSpells = [[NSMutableArray alloc] init];
        
        NSArray* spellNames = @[@"Arcesso Vallum Terrae", @"Claudo Animum"];
        NSArray* spellTranslations = @[@"Wall of Earth", @"Soul Shield"];
        NSArray* spellDescriptions = @[@"Invokes a wall of earth to block attacks.\n5 Defense, -5 Mana",
                                       @"Shields the user's soul for opponents.\n10 Defense, -10 Mana"];
        NSArray* spellStrengths = @[@5, @10];
        NSArray* spellCosts = @[@5, @10];
        
        for (int i = 0; i < [spellNames count]; i++) {
            Spell* spell = [[Spell alloc] initSpell:spellNames[i]
                                        translation:spellTranslations[i]
                                               desc:spellDescriptions[i]
                                               type: DEFEND
                                           strength:spellStrengths[i]
                                               cost:spellCosts[i]];
            [self.defenseSpells addObject:spell];
        }
    }
    
    return _defenseSpells;
}

// Returns a Spell object with the given spell name
- (Spell*)getSpellWithName:(NSString*)spellName {
    // Search through attack spells for the spell name
    for (int i = 0; i < [self.attackSpells count]; i++) {
        Spell* currentSpell = self.attackSpells[i];
        if ([currentSpell.name isEqualToString:spellName]) {
            return currentSpell;
        }
    }
    
    // Search through healing spells for the spell name
    for (int i = 0; i < [self.healingSpells count]; i++) {
        Spell* currentSpell = self.healingSpells[i];
        if ([currentSpell.name isEqualToString:spellName]) {
            return currentSpell;
        }
    }
    
    // Search through defense spells for the spell name
    for (int i = 0; i < [self.defenseSpells count]; i++) {
        Spell* currentSpell = self.defenseSpells[i];
        if ([currentSpell.name isEqualToString:spellName]) {
            return currentSpell;
        }
    }
    
    return nil;
}

// Add a data point and a label to the database for the current dataset ID
- (void)sendFeatureArray:(NSArray*)data withLabel:(NSString*)label {
    // setup the url
    NSString *baseURL = [NSString stringWithFormat:@"%@/AddDataPoint",self.SERVER_URL];
    NSURL *postUrl = [NSURL URLWithString:baseURL];
    
    // make an array of feature data
    // and place inside a dictionary with the label and dsid
    NSError *error = nil;
    NSDictionary *jsonUpload = @{@"feature":data,
                                 @"label":label,
                                 @"dsid":self.dsid};
    
    NSData *requestBody=[NSJSONSerialization dataWithJSONObject:jsonUpload options:NSJSONWritingPrettyPrinted error:&error];
    
    // create a custom HTTP POST request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:postUrl];
    
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:requestBody];
    
    // start the request, print the responses etc.
    NSURLSessionDataTask *postTask = [self.session dataTaskWithRequest:request completionHandler:nil];
    [postTask resume];
    
}


@end
