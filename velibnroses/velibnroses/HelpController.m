//
//  InfoController.m
//  OneBike
//
//  Created by Sébastien BALARD on 02/09/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import "HelpController.h"

@implementation HelpController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    NSString *path = @"IPContent-";
    path = [path stringByAppendingString:[[NSLocale preferredLanguages] objectAtIndex:0]];
    path = [path stringByAppendingString:@".png"];
    UIImage *content = [UIImage imageNamed:path];
    if (content != nil) {
        NSLog(@"@%@", path);
        [self.contentImage setImage:content];
    } else {
        NSLog(@"IPContent.png");
        [self.contentImage setImage:[UIImage imageNamed:@"IPContent.png"]];
    }
}

@end
