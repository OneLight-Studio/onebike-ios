//
//  RoutePolyline.h
//  Velib N' Roses
//
//  Created by Sébastien BALARD on 01/08/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import <MapKit/MapKit.h>

@interface RoutePolyline : NSObject <MKOverlay>

@property (nonatomic, strong) MKPolyline *polyline;

+ (RoutePolyline *)routePolylineFromPolyline:(MKPolyline *)otherPolyline;

@end
