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

@property (weak, nonatomic) IBOutlet UITableView *spellTableView;

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
        [self.castSpellBackground setBackgroundColor:[[UIColor alloc] initWithRed:200/255.f green:200/255.f blue:200/255.f alpha:1]];
//        [self.castSpellButton setTitleColor:[[UIColor alloc] initWithRed:255/255.f green:51/255.f blue:42/255.f alpha:1] forState:UIControlStateNormal];
        
        // Disable tab bar buttons
        for (UITabBarItem *tmpTabBarItem in [[self.tabBarController tabBar] items])
            [tmpTabBarItem setEnabled:NO];
    } else {
        double castingTime = fabs([self.startCastingTime timeIntervalSinceNow]);
        NSMutableArray* data = [self.ringBuffer getDataAsVector];
        data[0] = [NSNumber numberWithDouble:castingTime];
        self.lastData = data;
        
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

-(void)dealloc {
    [self.cmMotionManager stopDeviceMotionUpdates];
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

- (IBAction)yesNoClicked:(UIButton *)sender {
    self.castSpellButton.hidden = NO;
    self.castSpellButton.enabled = YES;
    [self.castSpellButton setTitle:@"Hold to Cast" forState:UIControlStateNormal];
    [self.castSpellButton setTitleColor:[[UIColor alloc] initWithRed:46/255.f green:79/255.f blue:147/255.f alpha:1] forState:UIControlStateNormal];
    self.predictedSpellImageView.hidden = YES;
    self.predictedSpellNameLabel.hidden = YES;
    self.yesButton.hidden = YES;
    self.noButton.hidden = YES;
    
    if ([sender.currentTitle isEqualToString:@"Yes"]) {
        [self.spellModel sendFeatureArray:self.lastData withLabel:self.lastLabel];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    if (section == 0) {
        return [self.spellModel.attackSpells count];
    } else if (section == 1) {
        return [self.spellModel.healingSpells count];
    } else {
        return [self.spellModel.defenseSpells count];
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSString *sectionName;
    switch (section)
    {
        case 0:
            sectionName = @"Attack Spells";
            break;
        case 1:
            sectionName = @"Healing Spells";
            break;
        case 2:
            sectionName = @"Defense Spells";
            break;
        default:
            sectionName = @"";
            break;
    }
    return sectionName;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SpellTableViewCell" forIndexPath:indexPath];
    
    // Configure the cell...
    Spell* spell;
    if (indexPath.section == 0) {
        spell = self.spellModel.attackSpells[indexPath.row];
    } else if (indexPath.section == 1) {
        spell = self.spellModel.healingSpells[indexPath.row];
    } else {
        spell = self.spellModel.defenseSpells[indexPath.row];
    }
    
    cell.imageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"%@ 100px", spell.name]];
    cell.textLabel.text = spell.name;
    cell.detailTextLabel.text = spell.translation;
    
    return cell;
}


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
             if(!error){
                 NSDictionary *responseData = [NSJSONSerialization JSONObjectWithData:data options: NSJSONReadingMutableContainers error: &error];
                 
                 NSString *name = [NSString stringWithFormat:@"%@",[responseData valueForKey:@"prediction"]];
                 name = [[name substringToIndex:[name length] - 2] substringFromIndex:3];
                 self.lastLabel = name;
                 
                 double accuracy = [[responseData objectForKey:name] doubleValue];
                 
                 NSLog(@"Name = %@, Accuracy = %f", name, accuracy);
                 
                 dispatch_async(dispatch_get_main_queue(), ^{
                     if ([self.spellModel getSpellWithName:name]) {
                         self.castSpellButton.hidden = YES;
                         self.predictedSpellImageView.hidden = NO;
                         self.predictedSpellNameLabel.hidden = NO;
                         self.yesButton.hidden = NO;
                         self.noButton.hidden = NO;
                         
                         self.predictedSpellNameLabel.text = [NSString stringWithFormat:@"%@?", name];
                         self.predictedSpellImageView.image = [UIImage imageNamed:name];
                     } else {
                         [self.castSpellButton setTitle:@"Hold to Cast" forState:UIControlStateNormal];
                         self.castSpellButton.enabled = YES;
                         [self.castSpellButton setTitleColor:[[UIColor alloc] initWithRed:46/255.f green:79/255.f blue:147/255.f alpha:1] forState:UIControlStateNormal];
                         UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Spell not found"
                                                                         message:@"Please train more."
                                                                        delegate:nil
                                                               cancelButtonTitle:@"OK"
                                                               otherButtonTitles:nil];
                         [alert show];
                     }
                     
                 });
             } else {
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


/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
