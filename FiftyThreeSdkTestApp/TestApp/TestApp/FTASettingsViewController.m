//
//  FTASettingsViewController.m
//  TestApp
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#import "FTASettingsViewController.h"

@interface FTASettingsViewController ()

@property (nonatomic, weak) UITableViewCell *frameRateCell;

@end

@implementation FTASettingsViewController

- (id)initWithStyle:(UITableViewStyle)style :(id<FTASettingsViewControllerDelegate>)andDelegate;
{
    self = [super initWithStyle:style];
    if (self) {
        _delegate = andDelegate;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        return 6;
    } else {
        return 2;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case 0:
            return @"Peripheral Properties";
        case 1:
            return @"Test App Parameters";
        default:
            return nil;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"TextCellForSettings";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];

    // Note any property on FTPenInformation may be nil, you need to deal with that case
    // gracefully.

    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }

    if (!self.info) {
        return cell;
    }
    if (indexPath.section == 0) {
        switch (indexPath.row) {
            case 0: {
                cell.textLabel.text = [NSString stringWithFormat:@"Name:%@", self.info.name];
                break;
            }
            case 1: {
                cell.textLabel.text = [NSString stringWithFormat:@"Manufacturer:%@", self.info.manufacturerName];
                break;
            }
            case 2: {
                cell.textLabel.text = [NSString stringWithFormat:@"Battery:%ld", (long)self.info.batteryLevel];
                break;
            }
            case 3: {
                cell.textLabel.text = [NSString stringWithFormat:@"Firmware:%@", self.info.firmwareRevision];
                break;
            }
            case 4: {
                cell.textLabel.text = [NSString stringWithFormat:@"Tip:%@", self.info.isTipPressed ? @"YES" : @"NO"];
                break;
            }
            case 5: {
                cell.textLabel.text = [NSString stringWithFormat:@"Eraser:%@", self.info.isEraserPressed ? @"YES" : @"NO"];
                break;
            }
        }
    } else {
        switch (indexPath.row) {
            case 0: {
                UISwitch *switchObj = [[UISwitch alloc] initWithFrame:CGRectMake(1.0, 1.0, 20.0, 20.0)];
                switchObj.on = [FTPenManager sharedInstance].automaticUpdatesEnabled;
                [switchObj addTarget:self action:@selector(toggleAutoUpdate:) forControlEvents:(UIControlEventValueChanged | UIControlEventTouchDragInside)];
                cell.textLabel.text = @"auto update";
                cell.accessoryView = switchObj;
                break;
            }
            case 1: {
                UISlider *framerateSlider = [[UISlider alloc] initWithFrame:CGRectMake(1.0, 1.0, 150.0, 20.0)];
                NSInteger fps = [self.delegate getFramerate];
                [framerateSlider setMaximumValue:120.0f];
                [framerateSlider setValue:fps animated:NO];
                [framerateSlider addTarget:self action:@selector(updateFramerate:) forControlEvents:(UIControlEventValueChanged)];
                [framerateSlider addTarget:self action:@selector(doneUpdatingFramerate:) forControlEvents:(UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventEditingDidEnd)];
                
                cell.accessoryView = framerateSlider;
                self.frameRateCell = cell;
                [self updateFramerateLabel];
                break;
            }
        }
    }
    return cell;
}

#pragma mark - Selectors
-(void)toggleAutoUpdate:(id)sender
{
    [FTPenManager sharedInstance].automaticUpdatesEnabled = [(UISwitch *)sender isOn];
}

- (void)updateFramerate:(id)sender
{
    UISlider *framerateSlider = (UISlider *)sender;
    [self.delegate setFramerate:[framerateSlider value]];
    [self updateFramerateLabel];
}

- (void)doneUpdatingFramerate:(id)sender
{
    UISlider *framerateSlider = (UISlider *)sender;
    [framerateSlider setValue:[self.delegate getFramerate] animated:YES];
    [self updateFramerateLabel];
}

#pragma mark - Label Updaters
- (void)updateFramerateLabel
{
    self.frameRateCell.textLabel.text = [NSString stringWithFormat:@"%ld fps", [self.delegate getFramerate]];
}

@end
