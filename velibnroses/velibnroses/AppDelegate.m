//
//  AppDelegate.m
//  velibnroses
//
//  Created by Thomas on 04/07/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import "AppDelegate.h"
#import "Constants.h"

@implementation AppDelegate {
    double _sleepingStartDate;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    UIImage *navBackgroundImage = [UIImage imageNamed:@"BarBg"];
    [[UINavigationBar appearance] setBackgroundImage:navBackgroundImage forBarMetrics:UIBarMetricsDefault];

    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    _sleepingStartDate = [[NSDate date] timeIntervalSince1970];
    NSLog(@"applicationDidEnterBackground");
    
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_DID_ENTER_BACKGROUND object:nil userInfo:nil];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    NSLog(@"applicationWillEnterForeground");
    double now = [[NSDate date] timeIntervalSince1970];
    double sleepingTime = now - _sleepingStartDate;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_WILL_ENTER_FOREGROUND object:[NSNumber numberWithDouble:sleepingTime] userInfo:nil];
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
