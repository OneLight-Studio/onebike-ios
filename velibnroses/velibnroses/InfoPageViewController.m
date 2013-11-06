//
//  AboutPageViewController.m
//  OneBike
//
//  Created by Sébastien BALARD on 11/10/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import "InfoPageViewController.h"
#import "UIUtils.h"
#import "Constants.h"

@interface InfoPageViewController ()

@property (strong,readwrite) UIViewController *helpScreen;
@property (strong,readwrite) UIViewController *aboutScreen;

@end

@implementation InfoPageViewController

# pragma mark -

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.delegate = self;
    self.dataSource = self;
    self.view.backgroundColor = [UIColor blackColor];
    self.navigationItem.hidesBackButton = YES;
	[self.backBarButton setBackgroundImage:[UIImage new] forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    [self.feedbackBarButton setBackgroundImage:[UIImage new] forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    self.helpScreen = [self.storyboard instantiateViewControllerWithIdentifier:@"helpScreen"];
    self.aboutScreen = [self.storyboard instantiateViewControllerWithIdentifier:@"aboutScreen"];
    [self setViewControllers:@[self.helpScreen] direction:UIPageViewControllerNavigationDirectionForward animated:YES completion:nil];
}

# pragma mark Event(s)

- (IBAction)backBarButtonClicked:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)feedbackBarButtonClicked:(id)sender {
    
    if ([MFMailComposeViewController canSendMail]) {
        NSString *emailTitle = NSLocalizedString(@"email_title", @"");
        NSArray *toRecipents = [NSArray arrayWithObject:EMAIL_RECIPIENT];
        
        MFMailComposeViewController *mailController = [[MFMailComposeViewController alloc] init];
        mailController.mailComposeDelegate = self;
        [[mailController navigationBar] setTitleTextAttributes:@{UITextAttributeTextColor:[UIColor whiteColor]}];
        [mailController setSubject:emailTitle];
        [mailController setToRecipients:toRecipents];
        
        float systemVersion = [[[UIDevice currentDevice] systemVersion] floatValue];
        if (systemVersion >= 7.0) {
            [[mailController navigationBar] setTintColor:[UIColor whiteColor]];
        }
        
        [self presentViewController:mailController animated:YES completion:NULL];
    } else {
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"dialog_error_title", @"") message:NSLocalizedString(@"no_email_account_defined", @"") delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil] show];
    }
}

# pragma mark -
# pragma mark UIPageViewControllerDataSource

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController {
    
    UIViewController *next = nil;
    
    if (viewController == self.helpScreen) {
        next = self.aboutScreen;
    }
    
    return next;
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController {
    
    UIViewController *previous = nil;
    
    if (viewController == self.aboutScreen) {
        previous = self.helpScreen;
    }
    
    return previous;
}

- (NSInteger)presentationIndexForPageViewController:(UIPageViewController *)pageViewController {
    return 0;
}

- (NSInteger)presentationCountForPageViewController:(UIPageViewController *)pageViewController {
    [self setupPageControlAppearance];
    return 2;
}

- (void)setupPageControlAppearance {
    UIPageControl *pageControl = [[self.view.subviews filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"(class = %@)", [UIPageControl class]]] lastObject];
    pageControl.pageIndicatorTintColor = [UIColor whiteColor];
    pageControl.currentPageIndicatorTintColor = [UIUtils colorWithHexaString:@"#afcb13"];
}

# pragma mark MFMailComposeViewControllerDelegate

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
    switch (result) {
        case MFMailComposeResultCancelled:
            NSLog(@"Mail cancelled");
            break;
        case MFMailComposeResultSaved:
            NSLog(@"Mail saved");
            break;
        case MFMailComposeResultSent:
            NSLog(@"Mail sent");
            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"dialog_info_title", @"") message:NSLocalizedString(@"thanks_feedback", @"") delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil] show];
            break;
        case MFMailComposeResultFailed:
            NSLog(@"Mail sent failure: %@", [error localizedDescription]);
            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"dialog_error_title", @"") message:[error localizedDescription] delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil] show];
            break;
        default:
            break;
    }
    [self dismissViewControllerAnimated:YES completion:NULL];
}

@end
