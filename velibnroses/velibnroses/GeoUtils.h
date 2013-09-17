//
//  GeoUtils.h
//  Velib N' Roses
//
//  Created by Sébastien BALARD on 17/07/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import <MapKit/MapKit.h>

@interface GeoUtils : NSObject

+ (double)getDistanceFromLat:(double)srcLatitude toLat:(double)destLatitude fromLong:(double)srcLongitude toLong:(double)destLongitude;
+ (MKPolyline *)polylineWithEncodedString:(NSString *)encodedString betweenDeparture:(CLLocationCoordinate2D)departure andArrival:(CLLocationCoordinate2D)arrival;
+ (BOOL)isLocation:(CLLocationCoordinate2D)location inRegion:(MKCoordinateRegion)region;
+ (double)getClusterSideLengthForZoomLevel:(int)level;

@end
