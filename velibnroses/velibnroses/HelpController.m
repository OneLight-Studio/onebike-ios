//
//  InfoController.m
//  OneBike
//
//  Created by Sébastien BALARD on 02/09/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import "HelpController.h"

@interface HelpController ()

@end

@implementation HelpController

@synthesize contentImage;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    NSString *path = NSLocalizedString(@"Images/HelpScreen/",@"");
    path = [path stringByAppendingString:[[NSLocale preferredLanguages] objectAtIndex:0]];
    path = [path stringByAppendingString:@"/IPContent"];
    NSLog(@"@%@", path);
    [self.contentImage setImage:[UIImage imageNamed:path]];
}

@end
