//
//  DuelViewController.m
//  Spellcast
//
//  Created by ch484-mac7 on 5/5/15.
//  Copyright (c) 2015 SMUJSJ. All rights reserved.
//

#import "DuelViewController.h"
#import <CoreMotion/CoreMotion.h>
#import "RingBuffer.h"
#import "SpellModel.h"

#define UPDATE_INTERVAL 1/10.0

@interface DuelViewController () <NSURLSessionTaskDelegate>

// for storing accelerometer updates
@property (strong, nonatomic) CMMotionManager *cmMotionManager;
@property (strong, nonatomic) NSOperationQueue *backQueue;
@property (strong, nonatomic) RingBuffer *ringBuffer;

// for the machine learning session
@property (strong,nonatomic) NSURLSession *session;
@property (strong,nonatomic) NSNumber *dsid;

@property (strong, nonatomic) SpellModel* spellModel;
@property (strong, nonatomic) MatchModel* matchModel;

@property (weak, nonatomic) IBOutlet UIProgressView *myHP;
@property (weak, nonatomic) IBOutlet UIProgressView *myMana;
@property (weak, nonatomic) IBOutlet UIView *myHPManaBackground;
@property (weak, nonatomic) IBOutlet UILabel *myName;
@property (weak, nonatomic) IBOutlet UIImageView *mySpell;
@property (nonatomic) float myDefense;

@property (weak, nonatomic) IBOutlet UIProgressView *theirHP;
@property (weak, nonatomic) IBOutlet UIProgressView *theirMana;
@property (weak, nonatomic) IBOutlet UIView *theirHPManaBackground;
@property (weak, nonatomic) IBOutlet UILabel *theirName;
@property (weak, nonatomic) IBOutlet UIImageView *theirSpell;
@property (nonatomic) float theirDefense;

@property (weak, nonatomic) IBOutlet UITextView *battleLog;

@property (weak, nonatomic) IBOutlet UIButton *castSpellButton;
@property (strong, nonatomic) NSDate *startCastingTime;
@property (nonatomic) BOOL casting;

@property (strong, nonatomic) NSTimer *manaTimer;

@end

@implementation DuelViewController

// Gets an instance of the SpellModel class using lazy instantiation
- (SpellModel*) spellModel {
    if(!_spellModel)
        _spellModel = [SpellModel sharedInstance];
    
    return _spellModel;
}

// Gets an instance of the MatchModel class using lazy instantiation
- (MatchModel*) matchModel {
    if(!_matchModel)
        _matchModel = [MatchModel sharedInstance];
    
    return _matchModel;
}

-(CMMotionManager*)cmMotionManager{
    if(!_cmMotionManager){
        _cmMotionManager = [[CMMotionManager alloc] init];
        
        if(![_cmMotionManager isDeviceMotionAvailable])
            _cmMotionManager = nil;
        else
            _cmMotionManager.deviceMotionUpdateInterval = UPDATE_INTERVAL;
    }
    return _cmMotionManager;
}

-(NSOperationQueue*)backQueue{
    
    if(!_backQueue){
        _backQueue = [[NSOperationQueue alloc] init];
    }
    return _backQueue;
}

-(RingBuffer*)ringBuffer{
    if(!_ringBuffer){
        _ringBuffer = [[RingBuffer alloc] init];
    }
    
    return _ringBuffer;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.dsid = self.spellModel.dsid;
    
    //setup NSURLSession (ephemeral)
    NSURLSessionConfiguration *sessionConfig =
    [NSURLSessionConfiguration ephemeralSessionConfiguration];
    
    sessionConfig.timeoutIntervalForRequest = 5.0;
    sessionConfig.timeoutIntervalForResource = 8.0;
    sessionConfig.HTTPMaximumConnectionsPerHost = 1;
    
    self.session =
    [NSURLSession sessionWithConfiguration:sessionConfig
                                  delegate:self
                             delegateQueue:nil];
    
    // setup acceleration monitoring
    [self.cmMotionManager startDeviceMotionUpdatesToQueue:self.backQueue withHandler:^(CMDeviceMotion *motion, NSError *error) {
        [_ringBuffer addNewData:motion.userAcceleration.x
                          withY:motion.userAcceleration.y
                          withZ:motion.userAcceleration.z];
    }];
}

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.matchModel updateWithViewController:self];
    
    // If no match is running, end the match
    if (![self.matchModel isMatchRunning]) {
        NSLog(@"end match");
        [self dismissViewControllerAnimated:YES completion:nil];
    }
    
    // Set the opponent's display name.
    GKPlayer* player = self.matchModel.match.players[0];
    NSString* playerName = player.displayName;
    playerName = [[playerName substringToIndex:[playerName length] - 1] substringFromIndex:2];
    self.theirName.text = playerName;
    [self createTimer];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    // End the match
    [self.manaTimer invalidate];
    [self.matchModel endMatch];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// If the state of casting changes, update buttons/predict a spell
- (void)setCasting:(BOOL)casting {
    _casting = casting;
    
    // If the user is casting
    if (casting == YES) {
        // Start casting time
        self.startCastingTime = [NSDate date];
        [self.ringBuffer reset];
        
        // Set button UI
        [self.castSpellButton setTitle:@"Casting..." forState:UIControlStateNormal];
        [self.castSpellButton setBackgroundColor:[[UIColor alloc] initWithRed:200/255.f
                                                                        green:200/255.f
                                                                         blue:200/255.f
                                                                        alpha:1]];
        
        // Disable tab bar buttons
        for (UITabBarItem *tmpTabBarItem in [[self.tabBarController tabBar] items])
            [tmpTabBarItem setEnabled:NO];
    } else {
        // User stopped casting
        
        // Find length of spell and add to feature set
        double castingTime = fabs([self.startCastingTime timeIntervalSinceNow]);
        NSMutableArray* data = [self.ringBuffer getDataAsVector];
        data[0] = [NSNumber numberWithDouble:castingTime];
        
        // Set button UI
        self.castSpellButton.enabled = NO;
        [self.castSpellButton setTitle:@"Predicting..." forState:UIControlStateNormal];
        [self.castSpellButton setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
        
        // Predict a spell
        [self predictFeature:data];
        
        // Enable tab bar buttons
        for (UITabBarItem *tmpTabBarItem in [[self.tabBarController tabBar] items])
            [tmpTabBarItem setEnabled:YES];
    }
}

// Create a timer to increment both users' mana
- (void)createTimer {
    // Invalidate old timer
    if ([self.manaTimer isValid]) {
        [self.manaTimer invalidate];
    }
    
    // Call the function to increment the mana every second.
    self.manaTimer = [NSTimer scheduledTimerWithTimeInterval:1
                                                       target:self
                                                     selector:@selector(incrementMana)
                                                     userInfo:nil
                                                      repeats:YES];
    
    [[NSRunLoop mainRunLoop] addTimer:self.manaTimer forMode:NSRunLoopCommonModes];
}

// Increment both users' mana
- (void)incrementMana {
    // If my mana is not full, increment
    if (self.myMana.progress - 0.01 >= 0.01 ) {
        self.myMana.progress = self.myMana.progress - 0.01;
    } else {
        self.myMana.progress = 0.0;
    }
    
    // If their mana is not full, increment
    if (self.theirMana.progress + 0.01 <= 1 ) {
        self.theirMana.progress = self.theirMana.progress + 0.01;
    } else {
        self.theirMana.progress = 1.0;
    }
}

// Handle a spell being cast
- (void)handleSpellCast:(NSString*)spellName
          spellAccuracy:(NSNumber*)spellAccuracy
                 caster:(int)caster {
    // Get spell with spellName
    Spell* spell = [self.spellModel getSpellWithName:spellName];
    
    // Get strength/accuracy of the spell
    float finalStrength = ([spell.strength floatValue]*[spellAccuracy floatValue])/100.0;
    
    // Get the cost of the spell
    float cost = [spell.cost floatValue]/100.0;
    
    NSString* newMove;
    
    // Set styling
    UIFont *font = [UIFont fontWithName:@"IowanOldStyle-Roman" size:14.0];
    UIFont *boldFont = [UIFont fontWithName:@"IowanOldStyle-Bold" size:14.0];
    int boldedLength;
    UIColor* textColor;
    UIColor* myColor = [[UIColor alloc] initWithRed:126/255.f
                                              green:232/255.f
                                               blue:255/255.f
                                              alpha:1]; // blue
    UIColor* theirColor = [[UIColor alloc] initWithRed:219/255.f
                                                 green:177/255.f
                                                  blue:246/255.f
                                                 alpha:1]; // purple
    if (caster == 0) {
        // The user is casting
        
        // If the user does not have enough mana to cast the spell, exit
        if (self.myMana.progress + cost > 1) {
            return;
        }
        
        // Set the spell image
        self.mySpell.image = [UIImage imageNamed:spellName];
        [UIView transitionWithView:self.mySpell duration:0.5 options:UIViewAnimationOptionTransitionFlipFromTop animations:nil completion:nil];
        
        // Decrement my mana
        self.myMana.progress = self.myMana.progress + cost;
        
        textColor = myColor;
        boldedLength = 4;
        
        // Determine type of spell cast and complete actions thusly
        if (spell.type == ATTACK) {
            // User is attacking
            
            // Calculate strenght of spell minus the opponent's defense
            float newStrength = finalStrength - self.theirDefense;
            if (newStrength < 0) {
                newStrength = 0;
            }
            
            // Update opponent's health and defense
            self.theirHP.progress = self.theirHP.progress - newStrength;
            self.theirDefense -= (finalStrength);
            if (self.theirDefense < 0) {
                self.theirDefense = 0;
            }
            
            // String for battle log
            textColor = theirColor;
            boldedLength = 6;
            newMove = [NSString stringWithFormat:@"Enemy: -%.0f HP %@\n", newStrength*1000, spellName];
            
        } else if (spell.type == HEALMAGIC) {
            // User is healing his/her magic
            
            // Add contribution to my mana
            self.myMana.progress = self.myMana.progress - (finalStrength);
            
            // String for battle log
            newMove = [NSString stringWithFormat:@"You: +%.0f Mana %@\n", finalStrength*1000, spellName];
        } else if (spell.type == HEALHEALTH) {
            // User is healing his/her health
            
            // Add contribution to my health
            self.myHP.progress = self.myHP.progress - (finalStrength);
            
            // String for battle log
            newMove = [NSString stringWithFormat:@"You: +%.0f HP %@\n", finalStrength*1000, spellName];
        }else if (spell.type == DEFEND) {
            // User is defending
            
            // Set my defense points
            if (self.myDefense < finalStrength) {
                self.myDefense = finalStrength;
            }
            
            // String for battle log
            newMove = [NSString stringWithFormat:@"You: %.0f Defense %@\n", finalStrength*1000, spellName];
        }
    } else {
        // The opponent is casting
        
        // If they do not have enough mana to cast the spell, exit
        if (self.theirMana.progress - cost < 0) {
            return;
        }
        
        // Change their spell image
        self.theirSpell.image = [UIImage imageNamed:spellName];
        [UIView transitionWithView:self.theirSpell duration:0.5 options:UIViewAnimationOptionTransitionFlipFromTop animations:nil completion:nil];
        
        // Decrement their mana
        self.theirMana.progress = self.theirMana.progress - cost;
        
        textColor = theirColor;
        boldedLength = 6;
        
        // Determine type of spell cast and complete actions thusly
        if (spell.type == ATTACK) {
            // Opponent is attacking the user
            
            // Calculate strenght of spell minus the the user's defense
            float newStrength = finalStrength - self.myDefense;
            if (newStrength < 0) {
                newStrength = 0;
            }
            
            // Update opponent's health and defense
            self.myHP.progress = self.myHP.progress + newStrength;
            self.myDefense -= (finalStrength);
            if (self.myDefense < 0) {
                self.myDefense = 0;
            }
            
            // String for battle log
            newMove = [NSString stringWithFormat:@"You: -%.0f HP %@\n", newStrength*1000, spellName];
            
            textColor = myColor;
            boldedLength = 4;
            
        } else if (spell.type == HEALMAGIC) {
            // Opponent is healing their magic
            
            // Add contribution to their mana
            self.theirMana.progress = self.theirMana.progress + (finalStrength);
            
            // String for battle log
            newMove = [NSString stringWithFormat:@"Enemy: +%.0f Mana %@\n", finalStrength*1000, spellName];
        } else if (spell.type == HEALHEALTH) {
            // Opponent is healing their health
            
            // Add contribution to their health
            self.theirHP.progress = self.theirHP.progress + (finalStrength);
            
            // String for battle log
            newMove = [NSString stringWithFormat:@"Enemy: +%.0f HP %@\n", finalStrength*1000, spellName];
        }else if (spell.type == DEFEND) {
            // Opponent is defending
            
            // Set their defense points
            if (self.theirDefense < finalStrength) {
                self.theirDefense = finalStrength;
            }
            
            // String for battle log
            newMove = [NSString stringWithFormat:@"Enemy: %.0f Defense %@\n", finalStrength*1000, spellName];
        }
    }
    
    // Add new move to battle log
    NSMutableAttributedString* attributedNewMove = [[NSMutableAttributedString alloc] initWithString:newMove attributes:@{NSForegroundColorAttributeName:textColor, NSFontAttributeName:font}];
    [attributedNewMove addAttribute:NSFontAttributeName value:boldFont range:NSMakeRange(0, boldedLength)];
    [self.battleLog.textStorage appendAttributedString:attributedNewMove];
    [self scrollBattleLogToBottom];
    
    // Check if game has ended
    if (self.myHP.progress == 1 || self.theirHP.progress == 0) {
        [self matchOver];
    }
}

// Check if the match is over
- (BOOL)isMatchOver {
    return [self.castSpellButton.currentTitle isEqualToString:@"Exit Match"];
}

// If the match is over, display a message and change UI
- (void)matchOver {
    if (![self isMatchOver]) {
        // Stop increasing mana
        [self.manaTimer invalidate];
        
        [self.castSpellButton setTitle:@"Exit Match" forState:UIControlStateNormal];
        
        // Display message saying if the user won/lost/tied
        NSString* message;
        if (self.myHP.progress == 1 && self.theirHP.progress == 0) {
            message = @"Tie.";
        } else if (self.myHP.progress == 1) {
            message = @"You Lose.";
            [self.matchModel sendMessage:@{@"command":@"youWin"} toPlayersInMatch:self.matchModel.match.players];
        } else if (self.theirHP.progress == 0) {
            message = @"You Win!";
            [self.matchModel sendMessage:@{@"command":@"youLose"} toPlayersInMatch:self.matchModel.match.players];
        }
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:message
                                                        message:nil
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }
}

// Scrolls to the bottom of the battle log
- (void)scrollBattleLogToBottom {
    if (self.battleLog.contentSize.height > self.battleLog.frame.size.height) {
        CGPoint offset = CGPointMake(0, self.battleLog.contentSize.height - self.battleLog.frame.size.height);
        [self.battleLog setContentOffset:offset animated:YES];
    }
}

// Set casting when the user is holding the casting button
- (IBAction)holdCastButton:(UIButton *)sender {
    if (![self isMatchOver]) {
        self.casting = YES;
    }
}

// Set casting or exit when the user lifts their finger
- (IBAction)releaseCastButton:(UIButton *)sender {
    if (![self isMatchOver]) {
        self.casting = NO;
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

// Set casting or exit when the user lifts their finger
- (IBAction)releaseCastButtonOutside:(UIButton *)sender {
    if (![self isMatchOver]) {
        self.casting = NO;
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

// Predict a spell
- (void)predictFeature:(NSMutableArray*)featureData {
    [self.castSpellButton setBackgroundColor:[UIColor whiteColor]];
    
    // send the server new feature data and request back a prediction of the class
    
    // setup the url
    NSString* baseURL = [NSString stringWithFormat:@"%@/PredictOneSVM",self.spellModel.SERVER_URL];
    NSURL* postUrl = [NSURL URLWithString:baseURL];
    
    // data to send in body of post request (send arguments as json)
    NSError* error = nil;
    NSDictionary* jsonUpload = @{@"feature":featureData,
                                 @"dsid":self.dsid};
    
    NSData* requestBody=[NSJSONSerialization dataWithJSONObject:jsonUpload options:NSJSONWritingPrettyPrinted error:&error];
    
    // create a custom HTTP POST request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:postUrl];
    
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:requestBody];
    
    // start the request, print the responses etc.
    NSURLSessionDataTask *postTask = [self.session dataTaskWithRequest:request
         completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
             if(!error) {
                 // Get response data
                 NSDictionary *responseData = [NSJSONSerialization JSONObjectWithData:data
                                                                              options:NSJSONReadingMutableContainers
                                                                                error:&error];
                 
                 // Get name of spell predicted
                 NSString *name = [NSString stringWithFormat:@"%@",[responseData valueForKey:@"prediction"]];
                 name = [[name substringToIndex:[name length] - 2] substringFromIndex:3];
                 NSNumber *accuracy = [responseData objectForKey:name];
                 
                 // Get accuaracy of spell predicted
                 NSLog(@"Name = %@, Accuracy = %f", name, [accuracy doubleValue]);
                 
                 dispatch_async(dispatch_get_main_queue(), ^{
                     Spell *spell = [self.spellModel getSpellWithName:name];
                     if (spell && [accuracy doubleValue] > 0.5) {
                         // Spell was found and was accurate enough
                         [self.matchModel sendMessage:@{@"spellName":name, @"spellAccuracy":accuracy}
                                     toPlayersInMatch:self.matchModel.match.players];
                         [self handleSpellCast:name spellAccuracy:accuracy caster:0];
                     } else {
                         // Spell was not found or was not accurate enough
                         self.mySpell.image = [UIImage imageNamed:@"question"];
                     }
                     
                     // If the match is not over, reset the button to "Hold to Cast"
                     if (![self.castSpellButton.currentTitle isEqualToString:@"Exit Match"]) {
                         [self.castSpellButton setTitle:@"Hold to Cast" forState:UIControlStateNormal];
                     }
                     self.castSpellButton.enabled = YES;
                     [self.castSpellButton setTitleColor:[[UIColor alloc] initWithRed:46/255.f
                                                                                green:79/255.f
                                                                                 blue:147/255.f
                                                                                alpha:1] forState:UIControlStateNormal];
                     
                     
                 });
             } else {
                 // Connection error
                 [self.castSpellButton setTitle:@"Hold to Cast" forState:UIControlStateNormal];
                 self.castSpellButton.enabled = YES;
                 [self.castSpellButton setTitleColor:[[UIColor alloc] initWithRed:46/255.f
                                                                            green:79/255.f
                                                                             blue:147/255.f
                                                                            alpha:1] forState:UIControlStateNormal];
                 
                 
                 UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Connection error"
                                                                 message:@"Please check your Internet connection."
                                                                delegate:nil
                                                       cancelButtonTitle:@"OK"
                                                       otherButtonTitles:nil];
                 [alert show];
             }
         }];
    [postTask resume];
}

#pragma mark GKMatchDelegate methods
- (void)match:(GKMatch *)match didFailWithError:(NSError *)error {
    NSLog(@"MATCH FAILED: %@", [error description]);
    
}

// If a player disconnects from the match, end the match
- (void)match:(GKMatch *)match
       player:(GKPlayer *)player
didChangeConnectionState:(GKPlayerConnectionState)state {
    
    NSLog(@"PLAYER CHANGED STATE: %@", [self.matchModel nameForPlayerState:state]);
    NSLog(@"Change Players: %@", self.matchModel.match.players);
    
    if (![self.matchModel isMatchRunning]) {
        NSLog(@"end match");
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

// When the user receives data, end match or handle spell cast
- (void)match:(GKMatch *)match didReceiveData:(NSData *)data fromRemotePlayer:(GKPlayer *)player {
    NSDictionary *message = (NSDictionary*)[NSKeyedUnarchiver unarchiveObjectWithData:data];
    NSLog(@"Received '%@' from %@", message, player.displayName);
    
    if ([[message objectForKey:@"command"] isEqualToString:@"youLose"]) {
        // Your opponent reports that you lost
        self.myHP = 0;
        [self matchOver];
    } else if ([[message objectForKey:@"command"] isEqualToString:@"youWin"]) {
        // Your opponent reports that you won
        self.theirHP = 0;
        [self matchOver];
    } else {
        // Your opponent cast a spell
        [self handleSpellCast:[message objectForKey:@"spellName"] spellAccuracy:[message objectForKey:@"spellAccuracy"] caster:1];
    }
}

@end
