//
//  GeoUtils.h
//  Velib N' Roses
//
//  Created by Sébastien BALARD on 17/07/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

@interface GeoUtils : NSObject

+ (double)getDistanceFromLat:(double)srcLatitude toLat:(double)destLatitude fromLong:(double)srcLongitude toLong:(double)destLongitude;

@end
