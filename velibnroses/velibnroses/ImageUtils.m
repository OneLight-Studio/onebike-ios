//
//  ImageUtils.m
//  Velib N' Roses
//
//  Created by Sébastien BALARD on 29/08/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import "ImageUtils.h"

@implementation ImageUtils

+ (UIImage*)placeBikes:(UIImage*)image onImage:(UIImage*)background {
    
    CGSize size = background.size;
    
    if ([UIScreen instancesRespondToSelector:@selector(scale)] && [[UIScreen mainScreen] scale] == 2.0f) {
        UIGraphicsBeginImageContextWithOptions(size, NO, 2.0f);
    } else {
        UIGraphicsBeginImageContext(size);
    }
    
    [background drawAtPoint:CGPointMake(0, 0)];
    [image drawAtPoint:CGPointMake(10, 0)];
    
    UIImage* result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return result;
}

+ (UIImage*)placeStands:(UIImage*)image onImage:(UIImage*)background {
    
    CGSize size = background.size;
    
    if ([UIScreen instancesRespondToSelector:@selector(scale)] && [[UIScreen mainScreen] scale] == 2.0f) {
        UIGraphicsBeginImageContextWithOptions(size, NO, 2.0f);
    } else {
        UIGraphicsBeginImageContext(size);
    }
    
    [background drawAtPoint:CGPointMake(0, 0)];
    [image drawAtPoint:CGPointMake(10,15)];
    
    UIImage* result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return result;
}

+ (UIImage*)drawBikesText:(NSString*)text {
    
    // set rect, size, font
    
    CGRect rect;
    switch (text.length) {
        case 1:
            rect = CGRectMake(5, 4, 16, 16);
            break;
        case 2:
            rect = CGRectMake(2, 4, 16, 16);
            break;
        default:
            break;
    }
    
    CGSize size = CGSizeMake(rect.size.width, rect.size.height);
    UIFont *font = [UIFont fontWithName:@"Helvetica-Bold" size:11];
    
    // retina display, double resolution
    
    if ([UIScreen instancesRespondToSelector:@selector(scale)] && [[UIScreen mainScreen] scale] == 2.0f) {
        UIGraphicsBeginImageContextWithOptions(size, NO, 2.0f);
    } else {
        UIGraphicsBeginImageContext(size);
    }
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // draw fill
    
    CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextSetTextDrawingMode(context, kCGTextFill);
    [text drawInRect:CGRectIntegral(rect) withFont:font];
    
    // convert to image and return
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
    
}

+ (UIImage*)drawStandsText:(NSString*)text {
    
    // set rect, size, font
    
    CGRect rect;
    switch (text.length) {
        case 1:
            rect = CGRectMake(5, 5, 16, 16);
            break;
        case 2:
            rect = CGRectMake(1, 5, 16, 16);
            break;
        default:
            break;
    }
    
    CGSize size = CGSizeMake(rect.size.width, rect.size.height);
    UIFont *font = [UIFont fontWithName:@"Helvetica-Bold" size:11];
    
    // retina display, double resolution
    
    if ([UIScreen instancesRespondToSelector:@selector(scale)] && [[UIScreen mainScreen] scale] == 2.0f) {
        UIGraphicsBeginImageContextWithOptions(size, NO, 2.0f);
    } else {
        UIGraphicsBeginImageContext(size);
    }
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // draw fill
    
    CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextSetTextDrawingMode(context, kCGTextFill);
    [text drawInRect:CGRectIntegral(rect) withFont:font];
    
    // convert to image and return
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
    
}

@end
