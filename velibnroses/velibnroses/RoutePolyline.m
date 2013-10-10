//
//  RoutePolyline.m
//  Velib N' Roses
//
//  Created by Sébastien BALARD on 01/08/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import "RoutePolyline.h"

@implementation RoutePolyline

@synthesize polyline;

+ (RoutePolyline *)routePolylineFromPolyline:(MKPolyline *)otherPolyline {
    RoutePolyline *overlay = [[RoutePolyline alloc] init];
    overlay.polyline = otherPolyline;
    return overlay;
}

#pragma mark MKOverlay

- (CLLocationCoordinate2D) coordinate {
    return [polyline coordinate];
}

- (MKMapRect) boundingMapRect {
    return [polyline boundingMapRect];
}

- (BOOL)intersectsMapRect:(MKMapRect)mapRect {
    return [polyline intersectsMapRect:mapRect];
}

@end
