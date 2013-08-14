//
//  PlaceAnnotation.h
//  Velib N' Roses
//
//  Created by Sébastien BALARD on 12/08/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import <MapKit/MapKit.h>

typedef enum
{
    kDeparture, kArrival, kStation
} PlaceAnnotationType;

@interface PlaceAnnotation : MKPointAnnotation

@property (nonatomic, assign) PlaceAnnotationType type;

@end
