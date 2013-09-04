//
//  InfoController.h
//  OneBike
//
//  Created by Sébastien BALARD on 02/09/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface InfoController : UIViewController

@property (weak, nonatomic) IBOutlet UIBarButtonItem *backBarButton;
@property (weak, nonatomic) IBOutlet UIImageView *contentImage;

- (IBAction)backBarButtonClicked:(id)sender;

@end
