//
//  FTAccountsViewController.m
//  iJenkins
//
//  Created by Ondrej Rafaj on 29/08/2013.
//  Copyright (c) 2013 Fuerte Innovations. All rights reserved.
//

#import "FTAccountsViewController.h"
#import "FTServerHomeViewController.h"
#import "FTNoAccountCell.h"
#import "FTAccountCell.h"
#import "FTIconCell.h"
#import "GCNetworkReachability.h"


@interface FTAccountsViewController ()

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *data;
@property (nonatomic, strong) NSArray *demoAccounts;

@property (nonatomic, strong) NSMutableDictionary *reachabilityCache;
@property (nonatomic, strong) NSMutableDictionary *reachabilityStatusCache;

@property (nonatomic, strong) NSTimer *reachabilityTimer;

@end


@implementation FTAccountsViewController


#pragma mark Initialization

- (id)init {
    self = [super init];
    if (self) {
        _reachabilityStatusCache = [NSMutableDictionary dictionary];
    }
    return self;
}

#pragma mark Layout

- (void)scrollToAccount:(FTAccount *)account {
    
}

#pragma mark Data

- (void)reloadData {
    [super.tableView reloadData];
}

#pragma mark Creating elements

- (void)createTableView {
    _data = [kAccountsManager accounts];
    _demoAccounts = [kAccountsManager demoAccounts];
    
    [super createTableView];
}

- (void)createTopButtons {
    UIBarButtonItem *add = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(didCLickAddItem:)];
    [self.navigationItem setLeftBarButtonItem:add];
    
    UIBarButtonItem *edit = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(didCLickEditItem:)];
    [self.navigationItem setRightBarButtonItem:edit];
}

- (void)createAllElements {
    [super createAllElements];
    
    [self createTableView];
    [self createTopButtons];
    
    [self setTitle:FTLangGet(@"Servers")];
}

#pragma mark View lifecycle

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [FTAPIConnector stopLoadingAll];
}

- (void)viewDidAppear:(BOOL)animated{
    if(_reachabilityTimer){
        [_reachabilityTimer invalidate];
        _reachabilityTimer = nil;
    }
    [self startRefreshTimer];
}

#pragma mark Actions

- (void)didCLickAddItem:(UIBarButtonItem *)sender {
    FTAddAccountViewController *c = [[FTAddAccountViewController alloc] init];
    [c setIsNew:YES];
    FTAccount *acc = [[FTAccount alloc] init];
    [c setAccount:acc];
    [c setDelegate:self];
    [c setTitle:FTLangGet(@"New Instance")];
    UINavigationController *nc = [[UINavigationController alloc] initWithRootViewController:c];
    [self presentViewController:nc animated:YES completion:^{
        
    }];
}

- (void)didCLickEditItem:(UIBarButtonItem *)sender {
    [super.tableView setEditing:!super.tableView.editing animated:YES];
    
    UIBarButtonSystemItem item;
    if (self.tableView.editing) {
        item = UIBarButtonSystemItemDone;
    }
    else {
        item = UIBarButtonSystemItemEdit;
    }
    UIBarButtonItem *edit = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:item target:self action:@selector(didCLickEditItem:)];
    [self.navigationItem setRightBarButtonItem:edit animated:YES];
}

#pragma mark Table view delegate and data source methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0:
            return ((_data.count > 0) ? _data.count : 1);
            break;
            
        case 1:
            return _demoAccounts.count;
            break;
            
        case 2:
            return 1;
            break;
            
        default:
            return 0;
            break;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0 && _data.count == 0) {
        return 100;
    }
    else {
        return 54;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0:
            return FTLangGet(@"Your accounts");
            break;
            
        case 1:
            return FTLangGet(@"Demo account");
            break;
            
        case 2:
            return FTLangGet(@"About");
            break;
            
        default:
            return nil;
            break;
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    if ((indexPath.section == 0 && _data.count == 0) || indexPath.section) {
        return NO;
    }
    else return (indexPath.section == 0);
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        FTAccount *acc = [_data objectAtIndex:indexPath.row];
        [kAccountsManager removeAccount:acc];
        [tableView reloadData];
    }
}

- (UITableViewCell *)cellForNoAccount {
    static NSString *identifier = @"noAccountCell";
    FTNoAccountCell *cell = [super.tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[FTNoAccountCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
    }
    return cell;
}

- (UITableViewCell *)accountCellForIndexPath:(NSIndexPath *)indexPath{
    static NSString *identifier = @"accountCell";
    FTAccountCell *cell = [super.tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[FTAccountCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
        
    }
    if (indexPath.section == 0) {
        [cell setAccessoryType:UITableViewCellAccessoryDetailDisclosureButton];
    }
    else {
        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
    }
// pasted
    [self checkReachabilityForItemAtIndexPath:indexPath AndCell:cell];
    
    //  Status of the server
    return cell;
}



- (void)checkReachabilityForItemAtIndexPath:(NSIndexPath *)indexPath
                                    AndCell:(FTAccountCell *)cell {
    
    __block FTAccount *nbacc = (indexPath.section == 0) ? [_data objectAtIndex:indexPath.row] : [_demoAccounts objectAtIndex:indexPath.row];
    
    __block FTAccount *acc = nbacc;
    
    [cell.textLabel setText:acc.name];
    NSString *port = (acc.port != 0) ? [NSString stringWithFormat:@":%d", acc.port] : @"";
    [cell.detailTextLabel setText:[NSString stringWithFormat:@"%@%@", acc.host, port]];
    
    NSNumber *key = @([acc hash]);
    NSNumber *statusNumber = _reachabilityStatusCache[key];
    
    if (acc.host.length > 0) {
        GCNetworkReachability *r = _reachabilityCache[acc.host];
        if (!r) {
            r = [GCNetworkReachability reachabilityWithHostName:acc.host];
            //  set the reachability cache to nil to get an update constantly.
            
            if (!_reachabilityCache) {
                _reachabilityCache = [NSMutableDictionary dictionary];
            }
            
            _reachabilityCache[acc.host] = r;
            [r startMonitoringNetworkReachabilityWithHandler:^(GCNetworkReachabilityStatus status) {
                __block FTAccountCellReachabilityStatus s = (status == GCNetworkReachabilityStatusNotReachable) ? FTAccountCellReachabilityStatusUnreachable : FTAccountCellReachabilityStatusReachable ;
                if (status == GCNetworkReachabilityStatusNotReachable) {
                    _reachabilityStatusCache[key] = @(s);
                    [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
                    
                    // **remove this comment once fixed** - Once the status becomes unreachable this block does not ever seem to be called again. Problem with logic?
                    // **SOLVED** - solution was to refresh the reachability cache. set reachability cache everytime the timer is updated to nil so it refreshes the reachability.
                    
                    NSLog(@"status is not reachable. ");
                }
                else {
                    NSLog(@"status is reachable. ");
                    _reachabilityStatusCache[key] = @(s);
                    [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
                   
                    
                    // TODO: Finish the API request to check server API, not just reachability
                    /*
                     [kAccountsManager setSelectedAccount:acc];
                     FTAPIOverallLoadDataObject *loadObject = [[FTAPIOverallLoadDataObject alloc] init];
                     [FTAPIConnector connectWithObject:loadObject andOnCompleteBlock:^(id<FTAPIDataAbstractObject> dataObject, NSError *error) {
                     if (error) {
                     s = FTAccountCellReachabilityStatusUnreachable;
                     }
                     else {
                     s = FTAccountCellReachabilityStatusReachable;
                     }
                     _reachabilityStatusCache[key] = @(s);
                     [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
                     }];
                     */
                }
            }];
        }
    }
    if (statusNumber) {
        cell.reachabilityStatus = [statusNumber unsignedIntegerValue];
    }
    else {
        cell.reachabilityStatus = FTAccountCellReachabilityStatusLoading;
        _reachabilityStatusCache[key] = @(FTAccountCellReachabilityStatusLoading);
    }
    
    
}

- (void )startRefreshTimer {
    _reachabilityTimer = [NSTimer scheduledTimerWithTimeInterval:3.0
                                     target:self
                                   selector:@selector(timerRun)
                                   userInfo:nil
                                    repeats:YES];
    
}

- (void )timerRun {
    // set reachability cache to nil so it refreshes the reachability
    _reachabilityCache = nil;
    
    // cells in section 1.
    NSMutableArray *cells;
    // cells in section 0
    NSMutableArray *cellsS0;
    
    for (NSInteger j = 0; j < [self.tableView numberOfSections]; ++j)
    {
        if([self.tableView numberOfRowsInSection:j] > 0){
        for (NSInteger i = 0; i < [self.tableView numberOfRowsInSection:j]; ++i)
        {
            if(j == 1){
            [cells addObject:[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:j]]];
            }
            
            if(j == 0){
            [cellsS0 addObject:[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:j]]];
            }
        }
        }
    }
    
    if(cells == nil){
        for(int i = 0; i < [cells count]; i++){
            [self checkReachabilityForItemAtIndexPath:[NSIndexPath indexPathForRow:i inSection:1] AndCell:[cells objectAtIndex:i]];
            NSLog(@"checking cell: %@", [[[cells objectAtIndex:i] textLabel] text]);
        }
    }
    
    if(cellsS0 == nil){
        for (int i = 0; i < [cellsS0 count]; i++){
            [self checkReachabilityForItemAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0] AndCell:[cells objectAtIndex:i]];
            NSLog(@"checking cell: %@", [[[cellsS0 objectAtIndex:i] textLabel] text]);
        }
    }
    
    

    
    [self.tableView reloadData];
    [self.tableView reloadInputViews];
    
}



- (FTBasicCell *)cellForAboutSection:(NSIndexPath *)indexPAth {
    static NSString *identifier = @"aboutSectionCell";
    FTIconCell *cell = [super.tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[FTIconCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
    }
    [cell.iconView setDefaultIconIdentifier:@"icon-github"];
    [cell.textLabel setText:FTLangGet(@"Open source project")];
    [cell.detailTextLabel setText:FTLangGet(@"All source code available on github.com")];
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0 && _data.count == 0) {
        return [self cellForNoAccount];
    }
    else {
        if (indexPath.section != 2) {
            return [self accountCellForIndexPath:indexPath];
        }
        else {
            return [self cellForAboutSection:indexPath];
        }
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0 && _data.count == 0) {
        [self didCLickAddItem:nil];
    }
    else {
        if (indexPath.section != 2) {
            FTAccount *acc = [self acccountForIndexPath:indexPath];
            [kAccountsManager setSelectedAccount:acc];
            [FTAPIConnector resetForAccount:acc];
            
            FTServerHomeViewController *c = [[FTServerHomeViewController alloc] init];
            [c setTitle:acc.name];
            [self.navigationController pushViewController:c animated:YES];
        }
        else {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://github.com/rafiki270/iJenkins"]];
        }
    }
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    FTAccount *acc = [self acccountForIndexPath:indexPath];
    FTAddAccountViewController *c = [[FTAddAccountViewController alloc] init];
    [c setDelegate:self];
    NSLog(@"%@",acc.name);
    [c setTitle:acc.name];
    [c setAccount:acc];
    
    UINavigationController *nc = [[UINavigationController alloc] initWithRootViewController:c];
    [self presentViewController:nc animated:YES completion:^{
        
    }];
}

#pragma mark Add account view controller delegate methods

- (void)addAccountViewController:(FTAddAccountViewController *)controller didAddAccount:(FTAccount *)account {
    [kAccountsManager addAccount:account];
    [self reloadData];
    [self scrollToAccount:account];
    [self dismissViewControllerAnimated:YES completion:^{
        
    }];
}

- (void)addAccountViewController:(FTAddAccountViewController *)controller didModifyAccount:(FTAccount *)account {
    [kAccountsManager updateAccount:account];
    [self reloadData];
    [self scrollToAccount:account];
    [self dismissViewControllerAnimated:YES completion:^{
        
    }];
}

- (void)addAccountViewControllerCloseWithoutSave:(FTAddAccountViewController *)controller {
    [self dismissViewControllerAnimated:YES completion:^{
        [controller resetAccountToOriginalStateIfNotNew];
        
    }];
}

#pragma mark Private methods

- (FTAccount *)acccountForIndexPath:(NSIndexPath *)indexPath {
    return (indexPath.section == 0) ? [_data objectAtIndex:indexPath.row] : [_demoAccounts objectAtIndex:indexPath.row];
}


@end
