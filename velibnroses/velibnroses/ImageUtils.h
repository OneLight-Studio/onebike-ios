//
//  ImageUtils.h
//  Velib N' Roses
//
//  Created by Sébastien BALARD on 29/08/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ImageUtils : NSObject

+ (UIImage*)placeBikes:(UIImage*)image onImage:(UIImage*)background;
+ (UIImage*)placeStands:(UIImage*)image onImage:(UIImage*)background;
+ (UIImage*)drawBikesText:(NSString*)text;
+ (UIImage*)drawStandsText:(NSString*)text;

@end
