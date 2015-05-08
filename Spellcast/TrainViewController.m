//
//  TestingViewController.m
//  Assignment6
//
//  Copyright (c) 2015 SMUJSJ. All rights reserved.
//

#import "TrainViewController.h"
#import <CoreMotion/CoreMotion.h>
#import "RingBuffer.h"
#import "SpellModel.h"

#define UPDATE_INTERVAL 1/10.0

@interface TrainViewController () <NSURLSessionTaskDelegate>

// for the machine learning session
@property (strong,nonatomic) NSURLSession *session;
@property (strong,nonatomic) NSNumber *dsid;

@property (strong, nonatomic) SpellModel* spellModel;

// The most recently predicted data and label, to be sent to the server for
// retraining if the user presses "Yes"
@property (strong, nonatomic) NSMutableArray* lastData;
@property (strong, nonatomic) NSString* lastLabel;

// for storing accelerometer updates
@property (strong, nonatomic) CMMotionManager *cmMotionManager;
@property (strong, nonatomic) NSOperationQueue *backQueue;
@property (strong, nonatomic) RingBuffer *ringBuffer;

@property (weak, nonatomic) IBOutlet UIButton *castSpellButton;
@property (weak, nonatomic) IBOutlet UIView *castSpellBackground;

@property (weak, nonatomic) IBOutlet UIImageView *predictedSpellImageView;
@property (weak, nonatomic) IBOutlet UILabel *predictedSpellNameLabel;
@property (weak, nonatomic) IBOutlet UIButton *yesButton;
@property (weak, nonatomic) IBOutlet UIButton *noButton;

@property (strong, nonatomic) NSDate *startCastingTime;
@property (nonatomic) BOOL casting;

@end

@implementation TrainViewController

// Gets an instance of the SpellModel class using lazy instantiation
- (SpellModel*)spellModel {
    if (!_spellModel)
        _spellModel = [SpellModel sharedInstance];
    
    return _spellModel;
}

- (CMMotionManager*)cmMotionManager {
    if(!_cmMotionManager) {
        _cmMotionManager = [[CMMotionManager alloc] init];
        
        if (![_cmMotionManager isDeviceMotionAvailable]) {
            _cmMotionManager = nil;
        } else {
            _cmMotionManager.deviceMotionUpdateInterval = UPDATE_INTERVAL;
        }
    }
    return _cmMotionManager;
}

- (NSOperationQueue*)backQueue {
    if (!_backQueue) {
        _backQueue = [[NSOperationQueue alloc] init];
    }
    return _backQueue;
}

- (RingBuffer*)ringBuffer {
    if (!_ringBuffer) {
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
        [self.castSpellBackground setBackgroundColor:[[UIColor alloc] initWithRed:200/255.f green:200/255.f blue:200/255.f alpha:1]];
        
        // Disable tab bar buttons
        for (UITabBarItem *tmpTabBarItem in [[self.tabBarController tabBar] items])
            [tmpTabBarItem setEnabled:NO];
    } else {
        double castingTime = fabs([self.startCastingTime timeIntervalSinceNow]);
        NSMutableArray* data = [self.ringBuffer getDataAsVector];
        data[0] = [NSNumber numberWithDouble:castingTime];
        self.lastData = data;
        
        self.castSpellButton.enabled = NO;
        [self.castSpellButton setTitle:@"Predicting..." forState:UIControlStateNormal];
        [self.castSpellButton setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
        [self predictFeature:data];
        
        // Enable tab bar buttons
        for (UITabBarItem *tmpTabBarItem in [[self.tabBarController tabBar] items])
            [tmpTabBarItem setEnabled:YES];
    }
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

- (void)dealloc {
    [self.cmMotionManager stopDeviceMotionUpdates];
}

// Change casting state when button is held down
- (IBAction)holdCastButton:(UIButton *)sender {
    self.casting = YES;
}

// Stop casting when the use lifts finger
- (IBAction)releaseCastButton:(UIButton *)sender {
    self.casting = NO;
}

// Stop casting when the use lifts finger
- (IBAction)releaseCastButtonOutside:(UIButton *)sender {
    self.casting = NO;
}

// When the yes/no buttons are clicked, update the UI and send feature data
// if appropriate
- (IBAction)yesNoClicked:(UIButton *)sender {
    // Change UI to display "Hold to Cast" instead of "Yes No"
    self.castSpellButton.hidden = NO;
    self.castSpellButton.enabled = YES;
    [self.castSpellButton setTitle:@"Hold to Cast" forState:UIControlStateNormal];
    [self.castSpellButton setTitleColor:[[UIColor alloc] initWithRed:46/255.f green:79/255.f blue:147/255.f alpha:1] forState:UIControlStateNormal];
    self.yesButton.hidden = YES;
    self.noButton.hidden = YES;
    
    // If the user clicked "Yes", send the feature data
    if ([sender.currentTitle isEqualToString:@"Yes"]) {
        [self.spellModel sendFeatureArray:self.lastData withLabel:self.lastLabel];
    }
    
    // Reset the displayed spell picture and name to default
    self.predictedSpellImageView.image = [UIImage imageNamed:@"train_icon"];
    self.predictedSpellNameLabel.text = @"Cast any spell!";
    [UIView transitionWithView:self.predictedSpellImageView duration:0.5 options:UIViewAnimationOptionTransitionFlipFromBottom animations:nil completion:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// Predict the spell that the user cast
- (void)predictFeature:(NSMutableArray*)featureData {
    [self.castSpellBackground setBackgroundColor:[[UIColor alloc] initWithRed:240/255.f green:240/255.f blue:240/255.f alpha:1]];
    
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
             // If not error was received
             if (!error) {
                 // Get response data
                 NSDictionary *responseData = [NSJSONSerialization JSONObjectWithData:data options: NSJSONReadingMutableContainers error: &error];
                 
                 // Get name of the spell predicted
                 NSString *name = [NSString stringWithFormat:@"%@",[responseData valueForKey:@"prediction"]];
                 name = [[name substringToIndex:[name length] - 2] substringFromIndex:3];
                 self.lastLabel = name;
                 
                 // Get accuracy of the spell predicted
                 double accuracy = [[responseData objectForKey:name] doubleValue];
                 
                 NSLog(@"Name = %@, Accuracy = %f", name, accuracy);
                 
                 // Update UI
                 dispatch_async(dispatch_get_main_queue(), ^{
                     if ([self.spellModel getSpellWithName:name]) {
                         // Valid spell name was found
                         
                         // Toggle displayed buttons
                         self.castSpellButton.hidden = YES;
                         self.yesButton.hidden = NO;
                         self.noButton.hidden = NO;
                         
                         // Show the cast spell name and image and animate flip
                         self.predictedSpellNameLabel.text = [NSString stringWithFormat:@"%@?", name];
                         self.predictedSpellImageView.image = [UIImage imageNamed:name];
                         [UIView transitionWithView:self.predictedSpellImageView duration:0.5 options:UIViewAnimationOptionTransitionFlipFromTop animations:nil completion:nil];
                         
                     } else {
                         // Invalid spell name
                         
                         // Toggle displayed buttons back to the original
                         [self.castSpellButton setTitle:@"Hold to Cast" forState:UIControlStateNormal];
                         self.castSpellButton.enabled = YES;
                         [self.castSpellButton setTitleColor:[[UIColor alloc] initWithRed:46/255.f green:79/255.f blue:147/255.f alpha:1] forState:UIControlStateNormal];
                         [self.castSpellButton setBackgroundColor:[UIColor whiteColor]];
                         
                         // Spell not found alert
                         UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Spell not found"
                                                                         message:@"Please train more."
                                                                        delegate:nil
                                                               cancelButtonTitle:@"OK"
                                                               otherButtonTitles:nil];
                         [alert show];
                     }
                 });
                 
             } else {
                 // Connection error
                 
                 // Toggle displayed buttons back to the original
                 [self.castSpellButton setTitle:@"Hold to Cast" forState:UIControlStateNormal];
                 self.castSpellButton.enabled = YES;
                 [self.castSpellButton setTitleColor:[[UIColor alloc] initWithRed:46/255.f green:79/255.f blue:147/255.f alpha:1] forState:UIControlStateNormal];
                 [self.castSpellButton setBackgroundColor:[UIColor whiteColor]];
                 
                 // Connection error alert
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

@end
