//
//  AlgorithmsTableViewController.m
//  Assignment6
//
//  Copyright (c) 2015 SMUJSJ. All rights reserved.
//

#import "AlgorithmsTableViewController.h"
#import "ResultsTableViewController.h"
#import "SpellModel.h"

@interface AlgorithmsTableViewController ()

@property (weak, nonatomic) SpellModel* spellModel;

@property (weak, nonatomic) IBOutlet UILabel *detailKNN;
@property (weak, nonatomic) IBOutlet UILabel *detailSVM;

@end

@implementation AlgorithmsTableViewController

// Gets an instance of the SpellModel class using lazy instantiation
- (SpellModel*) spellModel {
    if(!_spellModel)
        _spellModel = [SpellModel sharedInstance];
    
    return _spellModel;
}

//Called when the view loads the first time
- (void)viewDidLoad {
    [super viewDidLoad];
}

//Called every time the view appears
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    //Sets the overall accuracuy for the KNN model
    self.detailKNN.text = [NSString stringWithFormat:@"%0.2f%%",[self.spellModel getTotalAccuracy:0]];
    //Sets the overall accuracuy for the SVM model
    self.detailSVM.text = [NSString stringWithFormat:@"%0.2f%%",[self.spellModel getTotalAccuracy:1]];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return 2;
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    BOOL isVC = [[segue destinationViewController] isKindOfClass:[ResultsTableViewController class]];
    
    if(isVC) {
        NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:selectedIndexPath];
        ResultsTableViewController *vc = [segue destinationViewController];
        
        //Sets the title of the next table and saves the algorithm selected
        vc.title = cell.textLabel.text;
        vc.currentAlgorithm = selectedIndexPath.row;
    }

}

@end
