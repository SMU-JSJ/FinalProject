//
//  TrainingViewController.m
//  Assignment6
//
//  Copyright (c) 2015 SMUJSJ. All rights reserved.
//

#import "LearnViewController.h"
#import <CoreMotion/CoreMotion.h>
#import "RingBuffer.h"
#import "SpellModel.h"

#define UPDATE_INTERVAL 1/10.0

@interface LearnViewController () <NSURLSessionTaskDelegate>

// for the machine learning session
@property (strong,nonatomic) NSURLSession *session;
@property (strong,nonatomic) NSNumber *dsid;

@property (strong, nonatomic) SpellModel* spellModel;

// for storing accelerometer updates
@property (strong, nonatomic) CMMotionManager *cmMotionManager;
@property (strong, nonatomic) NSOperationQueue *backQueue;
@property (strong, nonatomic) RingBuffer *ringBuffer;

@property (weak, nonatomic) IBOutlet UILabel *spellNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *spellTranslationLabel;
@property (weak, nonatomic) IBOutlet UILabel *spellDescriptionLabel;
@property (weak, nonatomic) IBOutlet UIImageView *spellImageView;
@property (weak, nonatomic) IBOutlet UIButton *castSpellButton;
@property (weak, nonatomic) IBOutlet UIImageView *greenBackground;
@property (weak, nonatomic) IBOutlet UIImageView *redBackground;

@property (strong, nonatomic) NSDate *startCastingTime;
@property (nonatomic) BOOL casting;

@end

@implementation LearnViewController

// Gets an instance of the SpellModel class using lazy instantiation
- (SpellModel*) spellModel {
    if(!_spellModel)
        _spellModel = [SpellModel sharedInstance];
    
    return _spellModel;
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


- (void)setCasting:(BOOL)casting {
    _casting = casting;
    
    if (casting == YES) {
        self.startCastingTime = [NSDate date];
        [self.ringBuffer reset];
        [self.castSpellButton setTitle:@"Casting..." forState:UIControlStateNormal];
        [self.castSpellButton setBackgroundColor:[[UIColor alloc] initWithRed:200/255.f green:200/255.f blue:200/255.f alpha:1]];
        
        // Disable tab bar buttons
        for (UITabBarItem *tmpTabBarItem in [[self.tabBarController tabBar] items])
            [tmpTabBarItem setEnabled:NO];
    } else {
        double castingTime = fabs([self.startCastingTime timeIntervalSinceNow]);
        NSMutableArray* data = [self.ringBuffer getDataAsVector];
        data[0] = [NSNumber numberWithDouble:castingTime];
        
        [self.spellModel sendFeatureArray:data withLabel:self.spell.name];
        [self predictFeature:self.spell.name data:data];
        
        [self.castSpellButton setTitle:@"Hold to Cast" forState:UIControlStateNormal];
        [self.castSpellButton setBackgroundColor:[UIColor whiteColor]];
        
        
        // Enable tab bar buttons
        for (UITabBarItem *tmpTabBarItem in [[self.tabBarController tabBar] items])
            [tmpTabBarItem setEnabled:YES];
    }
}

- (IBAction)holdCastButton:(UIButton *)sender {
    self.casting = YES;
}

- (IBAction)releaseCastButton:(UIButton *)sender {
    self.casting = NO;
}

- (IBAction)releaseCastButtonOutside:(UIButton *)sender {
    self.casting = NO;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do any additional setup after loading the view.
    self.spellNameLabel.text = self.spell.name;
    self.spellTranslationLabel.text = self.spell.translation;
    self.spellDescriptionLabel.text = self.spell.desc;
    self.spellImageView.image = [UIImage imageNamed:self.spell.name];
    
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

-(void)dealloc {
    [self.cmMotionManager stopDeviceMotionUpdates];
}

- (void)predictFeature:(NSString*)actualSpellName data:(NSMutableArray*)featureData {
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
             if(!error){
                 NSDictionary *responseData = [NSJSONSerialization JSONObjectWithData:data options: NSJSONReadingMutableContainers error: &error];
                 
                 NSString *predictedSpellName = [NSString stringWithFormat:@"%@",[responseData valueForKey:@"prediction"]];
                 predictedSpellName = [[predictedSpellName substringToIndex:[predictedSpellName length] - 2] substringFromIndex:3];
                 
                 double accuracy = [[responseData objectForKey:predictedSpellName] doubleValue];
                 
                 NSLog(@"Name = %@, Accuracy = %f", predictedSpellName, accuracy);
                 
                 dispatch_async(dispatch_get_main_queue(), ^{
                     if ([actualSpellName isEqualToString:predictedSpellName] && accuracy > 0.5) {
                         // Correct spell
                         [UIView animateWithDuration:0.4 animations:^{
                             self.greenBackground.alpha = 1.0;
                         } completion:^(BOOL finished) {
                             [UIView animateWithDuration:0.4 animations:^{
                                 self.greenBackground.alpha = 0.0;
                             } completion:nil];
                         }];
                     } else {
                         // Incorrect spell
                         [UIView animateWithDuration:0.4 animations:^{
                             self.redBackground.alpha = 1.0;
                         } completion:^(BOOL finished) {
                             [UIView animateWithDuration:0.4 animations:^{
                                 self.redBackground.alpha = 0.0;
                             } completion:nil];
                         }];
                     }
                 });
             }
         }];
    [postTask resume];
}


@end
