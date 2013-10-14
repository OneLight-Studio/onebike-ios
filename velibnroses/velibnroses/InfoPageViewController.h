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
#import <MessageUI/MessageUI.h>

@interface InfoPageViewController : UIPageViewController <UIPageViewControllerDataSource, UIPageViewControllerDelegate, MFMailComposeViewControllerDelegate>

@property (weak, nonatomic) IBOutlet UIBarButtonItem *backBarButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *feedbackBarButton;
@property (nonatomic, retain) HelpController *helpScreen;
@property (nonatomic, retain) AboutController *aboutScreen;

- (IBAction)backBarButtonClicked:(id)sender;
- (IBAction)feedbackBarButtonClicked:(id)sender;

@end
