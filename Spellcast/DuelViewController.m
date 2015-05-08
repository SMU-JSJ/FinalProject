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
    
    // Stylize things with transluscent background
//    [self makeTransluscentBackground:self.battleLog style:@"black"];
//    [self makeTransluscentBackground:self.castSpellButton style:@"white"];
//    [self makeTransluscentBackground:self.myHPManaBackground style:@"black"];
//    [self makeTransluscentBackground:self.theirHPManaBackground style:@"black"];
}

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.matchModel updateWithViewController:self];
    
    if (![self.matchModel isMatchRunning]) {
        NSLog(@"end match");
        [self dismissViewControllerAnimated:YES completion:nil];
    }
    //Set the opponent's display name.
    GKPlayer* player = self.matchModel.match.players[0];
    NSString* playerName = player.displayName;
    playerName = [[playerName substringToIndex:[playerName length] - 1] substringFromIndex:2];
    self.theirName.text = playerName;
    [self createTimer];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self.manaTimer invalidate];
    [self.matchModel endMatch];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

//-(void)makeTransluscentBackground:(UIView*)view style:(NSString*)style {
//    view.backgroundColor = [UIColor clearColor];
//    UIToolbar* bgToolbar = [[UIToolbar alloc] initWithFrame:view.frame];
//    if ([style isEqualToString:@"white"]) {
//        bgToolbar.barStyle = UIBarStyleDefault;
//    } else {
//        bgToolbar.barStyle = UIBarStyleBlack;
//    }
//    [view.superview insertSubview:bgToolbar belowSubview:view];
//}

- (void)setCasting:(BOOL)casting {
    _casting = casting;
    
    if (casting == YES) {
        self.startCastingTime = [NSDate date];
        [self.ringBuffer reset];
        [self.castSpellButton setTitle:@"Casting..." forState:UIControlStateNormal];
        [self.castSpellButton setBackgroundColor:[[UIColor alloc] initWithRed:200/255.f green:200/255.f blue:200/255.f alpha:1]];
        //[self makeTransluscentBackground:self.castSpellButton style:@"black"];
        
        // Disable tab bar buttons
        for (UITabBarItem *tmpTabBarItem in [[self.tabBarController tabBar] items])
            [tmpTabBarItem setEnabled:NO];
    } else {
        double castingTime = fabs([self.startCastingTime timeIntervalSinceNow]);
        NSMutableArray* data = [self.ringBuffer getDataAsVector];
        data[0] = [NSNumber numberWithDouble:castingTime];
        
        //[self sendFeatureArray:data
        //             withLabel:self.spell.name];
        self.castSpellButton.enabled = NO;
        [self.castSpellButton setTitle:@"Predicting..." forState:UIControlStateNormal];
        [self.castSpellButton setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
        [self predictFeature:data];
        
        // Enable tab bar buttons
        for (UITabBarItem *tmpTabBarItem in [[self.tabBarController tabBar] items])
            [tmpTabBarItem setEnabled:YES];
    }
}

- (void)createTimer {
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

- (void)incrementMana {
    if (self.myMana.progress - 0.01 >= 0.01 ) {
        self.myMana.progress = self.myMana.progress - 0.01;
    } else {
        self.myMana.progress = 0.0;
    }
    
    if (self.theirMana.progress + 0.01 <= 1 ) {
        self.theirMana.progress = self.theirMana.progress + 0.01;
    } else {
        self.theirMana.progress = 1.0;
    }
}

- (void)handleSpellCast:(NSString*)spellName spellAccuracy:(NSNumber*)spellAccuracy caster:(int)caster {
    Spell* spell = [self.spellModel getSpellWithName:spellName];
    float finalStrength = ([spell.strength floatValue]*[spellAccuracy floatValue])/100.0;
    float cost = [spell.cost floatValue]/100.0;
    NSString* newMove;
    
    UIFont *font = [UIFont fontWithName:@"IowanOldStyle-Roman" size:14.0];
    UIFont *boldFont = [UIFont fontWithName:@"IowanOldStyle-Bold" size:14.0];
    int boldedLength;
    UIColor* textColor;
    UIColor* myColor = [[UIColor alloc] initWithRed:126/255.f green:232/255.f blue:255/255.f alpha:1]; // blue
    UIColor* theirColor = [[UIColor alloc] initWithRed:219/255.f green:177/255.f blue:246/255.f alpha:1]; // purple
    
    if (caster == 0) {
        if (self.myMana.progress + cost > 1) {
            return;
        }
        self.mySpell.image = [UIImage imageNamed:spellName];
        [UIView transitionWithView:self.mySpell duration:0.5 options:UIViewAnimationOptionTransitionFlipFromTop animations:nil completion:nil];
        self.myMana.progress = self.myMana.progress + cost;
        
        textColor = myColor;
        boldedLength = 4;
        
        if (spell.type == ATTACK) {
            float newStrength = finalStrength - self.theirDefense;
            if (newStrength < 0) {
                newStrength = 0;
            }
            
            self.theirHP.progress = self.theirHP.progress - newStrength;
            self.theirDefense -= (finalStrength);
            if (self.theirDefense < 0) {
                self.theirDefense = 0;
            }
            
            textColor = theirColor;
            boldedLength = 6;
            newMove = [NSString stringWithFormat:@"Enemy: -%.0f HP %@\n", newStrength*1000, spellName];
            
        } else if (spell.type == HEALMAGIC) {
            self.myMana.progress = self.myMana.progress - (finalStrength);
            newMove = [NSString stringWithFormat:@"You: +%.0f Mana %@\n", finalStrength*1000, spellName];
        } else if (spell.type == HEALHEALTH) {
            self.myHP.progress = self.myHP.progress - (finalStrength);
            newMove = [NSString stringWithFormat:@"You: +%.0f HP %@\n", finalStrength*1000, spellName];
        }else if (spell.type == DEFEND) {
            self.myDefense = finalStrength;
            newMove = [NSString stringWithFormat:@"You: %.0f Defense %@\n", finalStrength*1000, spellName];
        }
    } else {
        if (self.theirMana.progress - cost < 0) {
            return;
        }
        
        self.theirSpell.image = [UIImage imageNamed:spellName];
        [UIView transitionWithView:self.theirSpell duration:0.5 options:UIViewAnimationOptionTransitionFlipFromTop animations:nil completion:nil];
        self.theirMana.progress = self.theirMana.progress - cost;
        
        textColor = theirColor;
        boldedLength = 6;
        
        if (spell.type == ATTACK) {
            float newStrength = finalStrength - self.myDefense;
            if (newStrength < 0) {
                newStrength = 0;
            }
            
            self.myHP.progress = self.myHP.progress + newStrength;
            self.myDefense -= (finalStrength);
            if (self.myDefense < 0) {
                self.myDefense = 0;
            }
            
            newMove = [NSString stringWithFormat:@"You: -%.0f HP %@\n", newStrength*1000, spellName];
            
            textColor = myColor;
            boldedLength = 4;
            
        } else if (spell.type == HEALMAGIC) {
            self.theirMana.progress = self.theirMana.progress + (finalStrength);
            newMove = [NSString stringWithFormat:@"Enemy: +%.0f Mana %@\n", finalStrength*1000, spellName];
        } else if (spell.type == HEALHEALTH) {
            self.theirHP.progress = self.theirHP.progress + (finalStrength);
            newMove = [NSString stringWithFormat:@"Enemy: +%.0f HP %@\n", finalStrength*1000, spellName];
        }else if (spell.type == DEFEND) {
            self.theirDefense = finalStrength;
            newMove = [NSString stringWithFormat:@"Enemy: %.0f Defense %@\n", finalStrength*1000, spellName];
        }
    }
    
    
    NSMutableAttributedString* attributedNewMove = [[NSMutableAttributedString alloc] initWithString:newMove attributes:@{NSForegroundColorAttributeName:textColor, NSFontAttributeName:font}];
    [attributedNewMove addAttribute:NSFontAttributeName value:boldFont range:NSMakeRange(0, boldedLength)];
    [self.battleLog.textStorage appendAttributedString:attributedNewMove];
    [self scrollBattleLogToBottom];
    
    if (self.myHP.progress == 1 || self.theirHP.progress == 0) {
        [self matchOver];
    }
}

- (void)matchOver {
    // Stop increasing mana
    [self.manaTimer invalidate];
    
    [self.castSpellButton setTitle:@"Exit Match" forState:UIControlStateNormal];
    
    NSString* message;
    if (self.myHP.progress == 1 && self.theirHP.progress == 0) {
        message = @"Tie.";
    } else if (self.myHP.progress == 1) {
        message = @"You Lose.";
    } else if (self.theirHP.progress == 0) {
        message = @"You Win!";
    }
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:message
                                                    message:nil
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
    
}

- (void)scrollBattleLogToBottom {
    if (self.battleLog.contentSize.height > self.battleLog.frame.size.height) {
        CGPoint offset = CGPointMake(0, self.battleLog.contentSize.height - self.battleLog.frame.size.height);
        [self.battleLog setContentOffset:offset animated:YES];
    }
}

- (IBAction)holdCastButton:(UIButton *)sender {
    if (![sender.currentTitle isEqualToString:@"Exit Match"]) {
        self.casting = YES;
    }
}

- (IBAction)releaseCastButton:(UIButton *)sender {
    if (![sender.currentTitle isEqualToString:@"Exit Match"]) {
        self.casting = NO;
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (IBAction)releaseCastButtonOutside:(UIButton *)sender {
    if (![sender.currentTitle isEqualToString:@"Exit Match"]) {
        self.casting = NO;
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)predictFeature:(NSMutableArray*)featureData {
    [self.castSpellButton setBackgroundColor:[UIColor whiteColor]];
    //[self makeTransluscentBackground:self.castSpellButton style:@"white"];
    
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
                 NSDictionary *responseData = [NSJSONSerialization JSONObjectWithData:data options: NSJSONReadingMutableContainers error: &error];
                 
                 NSString* name = [NSString stringWithFormat:@"%@",[responseData valueForKey:@"prediction"]];
                 name = [[name substringToIndex:[name length] - 2] substringFromIndex:3];
                 NSNumber* accuracy = [responseData objectForKey:name];
                 NSLog(@"Name = %@, Accuracy = %f", name, [accuracy doubleValue]);
                 
                 dispatch_async(dispatch_get_main_queue(), ^{
                     Spell *spell = [self.spellModel getSpellWithName:name];
                     if (spell && [accuracy doubleValue] > 0.5) {
                         // Spell was found and was accurate enough
                         [self.matchModel sendMessage:@{@"spellName":name, @"spellAccuracy":accuracy} toPlayersInMatch:self.matchModel.match.players];
                         [self handleSpellCast:name spellAccuracy:accuracy caster:0];
                     } else {
                         // Spell was not found or was not accurate enough
                         self.mySpell.image = [UIImage imageNamed:@"question"];
                     }
                     
                     if (![self.castSpellButton.currentTitle isEqualToString:@"Exit Match"]) {
                         [self.castSpellButton setTitle:@"Hold to Cast" forState:UIControlStateNormal];
                     }
                     self.castSpellButton.enabled = YES;
                     [self.castSpellButton setTitleColor:[[UIColor alloc] initWithRed:46/255.f green:79/255.f blue:147/255.f alpha:1] forState:UIControlStateNormal];
                     
                     
                 });
             } else {
                 // Connection error
                 [self.castSpellButton setTitle:@"Hold to Cast" forState:UIControlStateNormal];
                 self.castSpellButton.enabled = YES;
                 [self.castSpellButton setTitleColor:[[UIColor alloc] initWithRed:46/255.f green:79/255.f blue:147/255.f alpha:1] forState:UIControlStateNormal];
                 
                 
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

-(void)match:(GKMatch *)match didReceiveData:(NSData *)data fromRemotePlayer:(GKPlayer *)player {
    NSDictionary* message = (NSDictionary*)[NSKeyedUnarchiver unarchiveObjectWithData:data];
    NSLog(@"Received '%@' from %@", message, player.displayName);
    
    [self handleSpellCast:[message objectForKey:@"spellName"] spellAccuracy:[message objectForKey:@"spellAccuracy"] caster:1];
}


/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
