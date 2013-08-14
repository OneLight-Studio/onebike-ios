//
//  PlaceAnnotation.m
//  Velib N' Roses
//
//  Created by Sébastien BALARD on 12/08/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import "PlaceAnnotation.h"

@implementation PlaceAnnotation

@synthesize type;

- (id)init {
    self = [super init];
    if (self) {
        type = kStation;
    }
    return self;
}

@end
