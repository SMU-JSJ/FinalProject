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
@property (weak, nonatomic) IBOutlet UILabel *myName;
@property (weak, nonatomic) IBOutlet UIImageView *mySpell;

@property (weak, nonatomic) IBOutlet UIProgressView *theirHP;
@property (weak, nonatomic) IBOutlet UIProgressView *theirMana;
@property (weak, nonatomic) IBOutlet UILabel *theirName;
@property (weak, nonatomic) IBOutlet UIImageView *theirSpell;

@property (weak, nonatomic) IBOutlet UILabel *battleLog;

@property (weak, nonatomic) IBOutlet UIButton *castSpellButton;
@property (strong, nonatomic) NSDate *startCastingTime;
@property (nonatomic) BOOL casting;

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
    
    if (![self.matchModel isMatchRunning]) {
        NSLog(@"end match");
        [self.matchModel endMatch];
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setCasting:(BOOL)casting {
    _casting = casting;
    
    if (casting == YES) {
        self.startCastingTime = [NSDate date];
        [self.ringBuffer reset];
        [self.castSpellButton setTitle:@"Casting..." forState:UIControlStateNormal];
        [self.castSpellButton setBackgroundColor:[[UIColor alloc] initWithRed:200/255.f green:200/255.f blue:200/255.f alpha:1]];
        //        [self.castSpellButton setTitleColor:[[UIColor alloc] initWithRed:255/255.f green:51/255.f blue:42/255.f alpha:1] forState:UIControlStateNormal];
        
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

- (void)predictFeature:(NSMutableArray*)featureData {
    [self.castSpellButton setBackgroundColor:[[UIColor alloc] initWithRed:240/255.f green:240/255.f blue:240/255.f alpha:1]];
    
    // send the server new feature data and request back a prediction of the class
    
    // setup the url
    NSString* baseURL = [NSString stringWithFormat:@"%@/PredictOneSVM",self.spellModel.SERVER_URL];
    NSURL *postUrl = [NSURL URLWithString:baseURL];
    
    // data to send in body of post request (send arguments as json)
    NSError *error = nil;
    NSDictionary *jsonUpload = @{@"feature":featureData,
                                 @"dsid":self.dsid};
    
    NSData *requestBody=[NSJSONSerialization dataWithJSONObject:jsonUpload options:NSJSONWritingPrettyPrinted error:&error];
    
    // create a custom HTTP POST request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:postUrl];
    
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:requestBody];
    
    // start the request, print the responses etc.
    NSURLSessionDataTask *postTask = [self.session dataTaskWithRequest:request
     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
         if(!error) {
             NSDictionary *responseData = [NSJSONSerialization JSONObjectWithData:data options: NSJSONReadingMutableContainers error: &error];
             
             NSString *name = [NSString stringWithFormat:@"%@",[responseData valueForKey:@"prediction"]];
             name = [[name substringToIndex:[name length] - 2] substringFromIndex:3];
             double accuracy = [[responseData objectForKey:name] doubleValue];
             NSLog(@"Name = %@, Accuracy = %f", name, accuracy);
             
             dispatch_async(dispatch_get_main_queue(), ^{
                 Spell *spell = [self.spellModel getSpellWithName:name];
                 if (spell && accuracy > 0.5) {
                     // Spell was found and was accurate enough
                     self.mySpell.image = [UIImage imageNamed:name];
                 } else {
                     // Spell was not found or was not accurate enough
                     self.mySpell.image = [UIImage imageNamed:@"question"];
                 }
                 
                 [self.castSpellButton setTitle:@"Hold to Cast" forState:UIControlStateNormal];
                 self.castSpellButton.enabled = YES;
                 [self.castSpellButton setTitleColor:[[UIColor alloc] initWithRed:46/255.f green:79/255.f blue:147/255.f alpha:1] forState:UIControlStateNormal];
                 
             });
         } else {
             // Connection error
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

- (IBAction)holdCastButton:(UIButton *)sender {
    self.casting = YES;
}

- (IBAction)releaseCastButton:(UIButton *)sender {
    self.casting = NO;
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
        [self.matchModel endMatch];
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

-(void)match:(GKMatch *)match didReceiveData:(NSData *)data fromRemotePlayer:(GKPlayer *)player {
    NSDictionary* message = (NSDictionary*)[NSKeyedUnarchiver unarchiveObjectWithData:data];
    NSLog(@"Received '%@' from %@", message, player.displayName);
//    
//    if ([[message objectForKey:@"command"] isEqualToString:@"start"]) {
//        [self startDuel];
//    }
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
