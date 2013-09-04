//
//  InfoController.m
//  OneBike
//
//  Created by Sébastien BALARD on 02/09/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import "InfoController.h"

@interface InfoController ()

@end

@implementation InfoController

@synthesize backBarButton;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationItem.hidesBackButton = YES;
	[self.backBarButton setBackgroundImage:[UIImage new] forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)backBarButtonClicked:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

@end
