//
//  AboutPageViewController.m
//  OneBike
//
//  Created by Sébastien BALARD on 11/10/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import "InfoPageViewController.h"
#import "UIUtils.h"

@interface InfoPageViewController ()
    
@end

@implementation InfoPageViewController

@synthesize backBarButton;
@synthesize helpScreen;
@synthesize aboutScreen;

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.delegate = self;
    self.dataSource = self;
    self.view.backgroundColor = [UIColor blackColor];
    self.navigationItem.hidesBackButton = YES;
	[self.backBarButton setBackgroundImage:[UIImage new] forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    helpScreen = [self.storyboard instantiateViewControllerWithIdentifier:@"helpScreen"];
    aboutScreen = [self.storyboard instantiateViewControllerWithIdentifier:@"aboutScreen"];
    [self setViewControllers:@[helpScreen] direction:UIPageViewControllerNavigationDirectionForward animated:YES completion:nil];
}

- (IBAction)backBarButtonClicked:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController {
    
    UIViewController *next = nil;
    
    if (viewController == helpScreen) {
        next = aboutScreen;
    }
    
    return next;
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController {
    
    UIViewController *previous = nil;
    
    if (viewController == aboutScreen) {
        previous = helpScreen;
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

@end
