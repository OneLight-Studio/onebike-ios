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
#import <MapKit/MapKit.h>

@implementation GeoUtils

+ (double)getDistanceFromLat:(double)srcLatitude toLat:(double)destLatitude fromLong:(double)srcLongitude toLong:(double)destLongitude {
    
    double distLat = (destLatitude - srcLatitude) * M_PI / 180.0;
    double distLong = (destLongitude - srcLongitude) * M_PI / 180.0;
    double radSrc = srcLatitude * M_PI / 180.0;
    double radDest = destLatitude * M_PI / 180.0;
    
    double a = sin(distLat/2) * sin(distLat/2) + sin(distLong/2) * sin(distLong/2) * cos(radSrc) * sin(radDest);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return (EARTH_RADIUS_IN_METERS * c);
}

// see http://stackoverflow.com/questions/9217274/how-to-decode-the-google-directions-api-polylines-field-into-lat-long-points-in
+ (MKPolyline *)polylineWithEncodedString:(NSString *)encodedString betweenDeparture:(CLLocationCoordinate2D)departure andArrival:(CLLocationCoordinate2D)arrival {
    const char *bytes = [encodedString UTF8String];
    NSUInteger length = [encodedString lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    NSUInteger idx = 0;
    
    NSUInteger count = length / 4;
    CLLocationCoordinate2D *coords = calloc(count, sizeof(CLLocationCoordinate2D));
    NSUInteger coordIdx = 0;
    
    float latitude = 0;
    float longitude = 0;
    coords[coordIdx++] = departure;
    while (idx < length) {
        char byte = 0;
        int res = 0;
        char shift = 0;
        
        do {
            byte = bytes[idx++] - 63;
            res |= (byte & 0x1F) << shift;
            shift += 5;
        } while (byte >= 0x20);
        
        float deltaLat = ((res & 1) ? ~(res >> 1) : (res >> 1));
        latitude += deltaLat;
        
        shift = 0;
        res = 0;
        
        do {
            byte = bytes[idx++] - 0x3F;
            res |= (byte & 0x1F) << shift;
            shift += 5;
        } while (byte >= 0x20);
        
        float deltaLon = ((res & 1) ? ~(res >> 1) : (res >> 1));
        longitude += deltaLon;
        
        float finalLat = latitude * 1E-5;
        float finalLon = longitude * 1E-5;
        
        CLLocationCoordinate2D coord = CLLocationCoordinate2DMake(finalLat, finalLon);
        coords[coordIdx++] = coord;
        
        if (coordIdx == count) {
            NSUInteger newCount = count + 10;
            coords = realloc(coords, newCount * sizeof(CLLocationCoordinate2D));
            count = newCount;
        }
    }
    if (coordIdx == count) {
        NSUInteger newCount = count + 1;
        coords = realloc(coords, newCount * sizeof(CLLocationCoordinate2D));
    }
    coords[coordIdx++] = arrival;
    
    MKPolyline *polyline = [MKPolyline polylineWithCoordinates:coords count:coordIdx];
    free(coords);
    
    return polyline;
}

+ (BOOL)isLocation:(CLLocationCoordinate2D)location inRegion:(MKCoordinateRegion)region {
    
    CLLocationCoordinate2D center = region.center;
    CLLocationCoordinate2D _northWestSpanCorner, _southEastSpanCorner;
    BOOL visible = false;
    
    _northWestSpanCorner.latitude  = center.latitude  - (region.span.latitudeDelta  / 2.0);
    _northWestSpanCorner.longitude = center.longitude - (region.span.longitudeDelta / 2.0);
    _southEastSpanCorner.latitude  = center.latitude  + (region.span.latitudeDelta  / 2.0);
    _southEastSpanCorner.longitude = center.longitude + (region.span.longitudeDelta / 2.0);
    
    if (location.latitude >= _northWestSpanCorner.latitude && location.latitude <= _southEastSpanCorner.latitude
       && location.longitude >= _northWestSpanCorner.longitude && location.longitude <= _southEastSpanCorner.longitude) {
           visible = true;
       }
    
    return visible;
}

+ (double)getClusterSideLengthForZoomLevel:(int)level {
    return pow(2, MAX_ZOOM_LEVEL - level) * 2.5;
}

+ (BOOL)isCoordinate:(CLLocationCoordinate2D)first equalToCoordinate:(CLLocationCoordinate2D)second {
    return (first.latitude == second.latitude) < 0.001 && (first.longitude == second.longitude) < 0.001;
}

@end
