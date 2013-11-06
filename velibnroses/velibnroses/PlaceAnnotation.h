//
//  PlaceAnnotation.h
//  Velib N' Roses
//
//  Created by Sébastien BALARD on 12/08/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import <MapKit/MapKit.h>
#import "Station.h"

typedef enum
{
    kDeparture, kArrival, kStation
} PlaceAnnotationType;

typedef enum
{
    kUndefined, kNearDeparture, kNearArrival
} PlaceAnnotationLocation;

@interface PlaceAnnotation : MKPointAnnotation <NSCopying>

@property (assign,readwrite) PlaceAnnotationType placeType;
@property (assign,readwrite) PlaceAnnotationLocation placeLocation;
@property (strong,readwrite) Station *placeStation;

@end
