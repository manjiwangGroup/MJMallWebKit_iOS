//
//  MJViewController.m
//  MJMallWebKit_iOS
//
//  Created by jgyhc on 02/02/2021.
//  Copyright (c) 2021 jgyhc. All rights reserved.
//

#import "MJViewController.h"
#import "WNJServiceWebViewController.h"

@interface MJViewController ()

@end

@implementation MJViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)openEvent:(id)sender {
    WNJServiceWebViewController *viewController = [[WNJServiceWebViewController alloc] init];
    viewController.url = @"https://wap.manjiwang.com/lustreMall/home?hiddenBack=true";
    [self.navigationController pushViewController:viewController animated:YES];
    
}

@end
