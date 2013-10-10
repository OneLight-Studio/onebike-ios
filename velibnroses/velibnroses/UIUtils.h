//
//  UIUtils.h
//  OneBike
//
//  Created by Sébastien BALARD on 30/08/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//
#import <MapKit/MapKit.h>

@interface UIUtils : NSObject

+ (UIImage*)drawBikesText:(NSString*)text;
+ (UIImage*)drawStandsText:(NSString*)text;
+ (UIImage*)placeBikes:(UIImage*)image onImage:(UIImage*)background;
+ (UIImage*)placeStands:(UIImage*)image onImage:(UIImage*)background;
+ (UIColor *)colorWithHexaString:(NSString *)hexa;
+ (NSUInteger)zoomLevel:(MKMapView *)aMapView;

@end
