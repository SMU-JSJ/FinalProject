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
            desc:(NSString*) desc;

// The Latin name of the spell
@property (strong, nonatomic) NSString* name;
// The English translation of the spell
@property (strong, nonatomic) NSString* translation;
// The description of the spell
@property (strong, nonatomic) NSString* desc;

// Counts of correct predictions and total predictions for this spell using
// either the KNN or SVM algorithm
@property (strong, nonatomic) NSNumber* correctKNN;
@property (strong, nonatomic) NSNumber* totalKNN;
@property (strong, nonatomic) NSNumber* correctSVM;
@property (strong, nonatomic) NSNumber* totalSVM;

// Function for getting the prediction accuracy of this spell under a certain algorithm
- (double)getAccuracy:(NSInteger)algorithm;


// Note: add attack/heal/defense points later (for final project)

@end
