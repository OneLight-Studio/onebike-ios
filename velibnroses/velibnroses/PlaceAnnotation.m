//
//  PlaceAnnotation.m
//  Velib N' Roses
//
//  Created by Sébastien BALARD on 12/08/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import "PlaceAnnotation.h"

@implementation PlaceAnnotation

@synthesize placeType;
@synthesize placeLocation;
@synthesize placeStation;

- (id)init {
    self = [super init];
    if (self) {
        placeType = kStation;
        placeLocation = kUndefined;
    }
    return self;
}

@end
