//
//  AboutPageViewController.h
//  OneBike
//
//  Created by Sébastien BALARD on 11/10/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "HelpController.h"
#import "AboutController.h"

@interface InfoPageViewController : UIPageViewController <UIPageViewControllerDataSource, UIPageViewControllerDelegate>

@property (weak, nonatomic) IBOutlet UIBarButtonItem *backBarButton;
@property (nonatomic, retain) HelpController *helpScreen;
@property (nonatomic, retain) AboutController *aboutScreen;

- (IBAction)backBarButtonClicked:(id)sender;

@end
