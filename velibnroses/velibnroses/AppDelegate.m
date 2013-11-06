//
//  AppDelegate.m
//  velibnroses
//
//  Created by Thomas on 04/07/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import "AppDelegate.h"
#import "Constants.h"
#import "Keys.h"
#import "UIUtils.h"
#import "iRate.h"
#import "AFNetworkActivityIndicatorManager.h"

@interface AppDelegate ()

@property (assign,readwrite) double sleepingStartDate;

@end

@implementation AppDelegate

+ (void)initialize
{
    //configure iRate
    [iRate sharedInstance].usesUntilPrompt = 10;
    [iRate sharedInstance].daysUntilPrompt = 15;
    [iRate sharedInstance].remindPeriod = 15;
    [iRate sharedInstance].promptAgainForEachNewVersion = YES;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    float systemVersion = [[[UIDevice currentDevice] systemVersion] floatValue];
    if (systemVersion >= 7.0) {
        [[UINavigationBar appearance] setTintColor:[UIColor whiteColor]];
        [[UINavigationBar appearance] setBarTintColor:[UIUtils colorWithHexaString:@"#afcb13"]];
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
    } else {
        [[UINavigationBar appearance] setBackgroundImage:[UIImage imageNamed:@"NBBg.png"] forBarMetrics:UIBarMetricsDefault];
    }
    [[AFNetworkActivityIndicatorManager sharedManager] setEnabled:YES];
    [TestFlight takeOff:KEY_TESTFLIGHT];

    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    self.sleepingStartDate = [[NSDate date] timeIntervalSince1970];
    NSLog(@"applicationDidEnterBackground");
    
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_DID_ENTER_BACKGROUND object:nil userInfo:nil];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    NSLog(@"applicationWillEnterForeground");
    double now = [[NSDate date] timeIntervalSince1970];
    double sleepingTime = now - self.sleepingStartDate;
    NSLog(@"sleeping time : %f s", sleepingTime);
    if (sleepingTime > TIME_BEFORE_REFRESH_DATA_IN_SECONDS) {
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_WILL_ENTER_FOREGROUND object:nil userInfo:nil];
    }
    self.sleepingStartDate = 0;
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
