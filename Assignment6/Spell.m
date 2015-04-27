//
//  Spell.m
//  Assignment6
//
//  Created by ch484-mac7 on 4/12/15.
//  Copyright (c) 2015 SMUJSJ. All rights reserved.
//

#import "Spell.h"

@implementation Spell

// Synthesize, since both getter and setter are overriden
@synthesize correctKNN = _correctKNN;
@synthesize totalKNN = _totalKNN;
@synthesize correctSVM = _correctSVM;
@synthesize totalSVM = _totalSVM;

// Constructor
- (id) initSpell:(NSString*) name
     translation:(NSString*) translation
            desc:(NSString*) desc
{
    self = [super init];
    
    // Set member variables
    if (self) {
        self.name = name;
        self.translation = translation;
        self.desc = desc;
    }
    
    return self;
}

- (NSNumber*)correctKNN {
    if(!_correctKNN) {
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        NSArray* accuracyArray = [defaults arrayForKey:self.name];
        if(!accuracyArray) {
            _correctKNN = @0;
        } else {
           _correctKNN = accuracyArray[0];
        }
    }
    return _correctKNN;
}

- (void)setCorrectKNN:(NSNumber*)correctKNN {
    _correctKNN = correctKNN;
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:@[correctKNN, self.totalKNN, self.correctSVM, self.totalSVM] forKey:self.name];
    [defaults synchronize];
}

- (NSNumber*)totalKNN {
    if(!_totalKNN) {
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        NSArray* accuracyArray = [defaults arrayForKey:self.name];
        if(!accuracyArray) {
            _totalKNN = @0;
        } else {
            _totalKNN = accuracyArray[1];
        }
    }
    return _totalKNN;
}

- (void)setTotalKNN:(NSNumber*)totalKNN {
    _totalKNN = totalKNN;
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:@[self.correctKNN, totalKNN, self.correctSVM, self.totalSVM] forKey:self.name];
    [defaults synchronize];
}

- (NSNumber*)correctSVM {
    if(!_correctSVM) {
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        NSArray* accuracyArray = [defaults arrayForKey:self.name];
        if(!accuracyArray) {
            _correctSVM = @0;
        } else {
            _correctSVM = accuracyArray[2];
        }
    }
    return _correctSVM;
}

- (void)setCorrectSVM:(NSNumber*)correctSVM {
    _correctSVM = correctSVM;
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:@[self.correctKNN, self.totalKNN, correctSVM, self.totalSVM] forKey:self.name];
    [defaults synchronize];
}

- (NSNumber*)totalSVM {
    if(!_totalSVM) {
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        NSArray* accuracyArray = [defaults arrayForKey:self.name];
        if(!accuracyArray) {
            _totalSVM = @0;
        } else {
            _totalSVM = accuracyArray[3];
        }
    }
    return _totalSVM;
}

- (void)setTotalSVM:(NSNumber*)totalSVM {
    _totalSVM = totalSVM;
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:@[self.correctKNN, self.totalKNN, self.correctSVM, totalSVM] forKey:self.name];
    [defaults synchronize];
}

// Function for getting the prediction accuracy of this spell under a certain algorithm
- (double)getAccuracy:(NSInteger)algorithm {
    if (algorithm == 0) {
        // K-Nearest Neighbors
        if ([self.totalKNN intValue] == 0) {
            return 0;
        }
        return (double)[self.correctKNN intValue]/[self.totalKNN intValue] * 100;
    } else {
        // Support Vector Machine
        if([self.totalSVM intValue] == 0) {
            return 0;
        }
        return (double)[self.correctSVM intValue]/[self.totalSVM intValue] * 100;
    }
}

@end
