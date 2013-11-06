//
//  PlaceService.m
//  OneBike
//
//  Created by Sébastien BALARD on 28/10/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import "PlaceService.h"
#import "GeoUtils.h"

@implementation PlaceService

- (BOOL)areInTheSameContractsDeparture:(Place *)aDeparture AndArrival:(Place *)anArrival {
    return [aDeparture.contract isEqual:anArrival.contract];
}

- (double)getDistanceBetweenDeparture:(Place *)aDeparture andArrival:(Place *)anArrival betweenMinRadius:(double)minRadius andMaxRadius:(double)maxRadius {
    double dist = [GeoUtils getDistanceFromLat:aDeparture.location.coordinate.latitude toLat:anArrival.location.coordinate.latitude fromLong:aDeparture.location.coordinate.longitude toLong:anArrival.location.coordinate.longitude];
    dist /= 2;
    if (dist > maxRadius) {
        dist = maxRadius;
    } else if (dist < minRadius) {
        dist = minRadius;
    }
    NSLog(@"max search radius : %f m", dist);
    return dist;
}

- (BOOL)isSamePlaceBetween:(Place *)first and:(Place *)second {
    return fabs(first.location.coordinate.latitude - second.location.coordinate.latitude) < 0.001 && fabs(first.location.coordinate.longitude - second.location.coordinate.longitude) < 0.001;
}

@end
