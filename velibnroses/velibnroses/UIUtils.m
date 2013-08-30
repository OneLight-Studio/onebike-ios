//
//  UIUtils.m
//  OneBike
//
//  Created by Sébastien BALARD on 30/08/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import "UIUtils.h"

@implementation UIUtils

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

#pragma mark Color

+ (UIColor *)colorWithHexaString:(NSString *)hexa
{
    
    // Convert hex string to an integer
    unsigned int hexInt = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hexa];
    // Tell scanner to skip the # character
    [scanner setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@"#"]];
    // Scan hex value
    [scanner scanHexInt:&hexInt];
    
    // Create color object, specifying alpha as well
    UIColor *color =
    [UIColor colorWithRed:((CGFloat) ((hexInt & 0xFF0000) >> 16)) / 255 green:((CGFloat) ((hexInt & 0xFF00) >> 8)) / 255 blue:((CGFloat) (hexInt & 0xFF)) / 255 alpha:1.0];
    
    return color;
}

@end
