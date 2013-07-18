//
//  GeoUtils.m
//  Velib N' Roses
//
//  Created by Sébastien BALARD on 17/07/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import "GeoUtils.h"
#import <math.h>
#import "Constants.h"

@implementation GeoUtils

+ (double)getDistanceFromLat:(double)srcLatitude toLat:(double)destLatitude fromLong:(double)srcLongitude toLong:(double)destLongitude {
    
    double distLat = (destLatitude - srcLatitude) * M_PI / 180.0;
    double distLong = (destLongitude - srcLongitude) * M_PI / 180.0;
    double radSrc = srcLatitude * M_PI / 180.0;
    double radDest = destLatitude * M_PI / 180.0;
    
    double a = sin(distLat/2) * sin(distLat/2) * sin(distLong/2) * sin(distLong/2) * cos(radSrc) * sin(radDest);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return (EARTH_RADIUS_IN_METERS * c);
}

@end
