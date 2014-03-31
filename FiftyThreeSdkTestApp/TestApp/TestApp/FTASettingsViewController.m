//
//  FTASettingsViewController.m
//  TestApp
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#import "FTASettingsViewController.h"

@interface FTASettingsViewController ()
@end

@implementation FTASettingsViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
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
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0)
    {
        return 7;
    }
    else
    {
        return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"TextCellForSettings";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier ];

    // Note any property on FTPenInformation may be nil, you need to deal with that case
    // gracefully.

    if (cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:CellIdentifier];
    }

    if (!self.info)
    {
        return cell;
    }
    switch (indexPath.row)
    {
        case 0:
        {
            [cell setText:[NSString stringWithFormat:@"Name:%@", self.info.name]];
            break;
        }
        case 1:
        {
            [cell setText:[NSString stringWithFormat:@"Manufacturer:%@", self.info.manufacturerName]];
            break;
        }
        case 2:
        {
            [cell setText:[NSString stringWithFormat:@"Battery:%@ %%", self.info.batteryLevel]];
            break;
        }
        case 3:
        {
            [cell setText:[NSString stringWithFormat:@"Firmware:%@", self.info.firmwareRevision]];
            break;
        }
        case 4:
        {
            [cell setText:[NSString stringWithFormat:@"Learn:%@", self.info.learnMoreURL]];
            break;
        }
        case 5:
        {
            [cell setText:[NSString stringWithFormat:@"Tip:%@", self.info.isTipPressed?@"YES":@"NO"]];
            break;
        }
        case 6:
        {
            [cell setText:[NSString stringWithFormat:@"Eraser:%@", self.info.isEraserPressed?@"YES":@"NO"]];
            break;
        }
    }

    return cell;
}
@end
