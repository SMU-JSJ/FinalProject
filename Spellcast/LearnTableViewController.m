//
//  TrainingTableViewController.m
//  Assignment6
//
//  Copyright (c) 2015 SMUJSJ. All rights reserved.
//

#import "LearnTableViewController.h"
#import "SpellModel.h"
#import "LearnViewController.h"

@interface LearnTableViewController ()

@property (strong, nonatomic) SpellModel* spellModel;

@end

@implementation LearnTableViewController

// Gets an instance of the SpellModel class using lazy instantiation
- (SpellModel*) spellModel {
    if(!_spellModel)
        _spellModel = [SpellModel sharedInstance];
    
    return _spellModel;
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

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *sectionName;
    switch (section) {
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
    
    // Determine which spell goes with this table cell
    Spell* spell;
    if (indexPath.section == 0) {
        spell = self.spellModel.attackSpells[indexPath.row];
    } else if (indexPath.section == 1) {
        spell = self.spellModel.healingSpells[indexPath.row];
    } else {
        spell = self.spellModel.defenseSpells[indexPath.row];
    }
    
    // Configure the cell...
    cell.imageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"%@ 100px", spell.name]];
    cell.textLabel.text = spell.name;
    cell.detailTextLabel.text = spell.translation;
    
    return cell;
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    BOOL isVC = [[segue destinationViewController] isKindOfClass:[LearnViewController class]];
    
    if (isVC) {
        NSIndexPath *indexPath = [self.tableView indexPathForCell:sender];
        LearnViewController *vc = [segue destinationViewController];
        
        // Find the spell associated with the chosen table cell and send it to the VC
        Spell* spell;
        if (indexPath.section == 0) {
            spell = self.spellModel.attackSpells[indexPath.row];
        } else if (indexPath.section == 1) {
            spell = self.spellModel.healingSpells[indexPath.row];
        } else {
            spell = self.spellModel.defenseSpells[indexPath.row];
        }
        vc.spell = spell;
    }
}

@end
