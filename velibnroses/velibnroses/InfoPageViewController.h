//
//  AboutPageViewController.h
//  OneBike
//
//  Created by Sébastien BALARD on 11/10/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>

@interface InfoPageViewController : UIPageViewController <UIPageViewControllerDataSource, UIPageViewControllerDelegate, MFMailComposeViewControllerDelegate>

@property (weak,readwrite) IBOutlet UIBarButtonItem *backBarButton;
@property (weak,readwrite) IBOutlet UIBarButtonItem *feedbackBarButton;

- (IBAction)backBarButtonClicked:(id)sender;
- (IBAction)feedbackBarButtonClicked:(id)sender;

@end
