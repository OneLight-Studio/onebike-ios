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

- (id)copyWithZone:(NSZone *)zone
{
    id copy = [[[self class] alloc] init];
    
    if (copy) {
        
        // Set primitives
        [copy setCoordinate:self.coordinate];
        [copy setPlaceType:self.placeType];
        [copy setPlaceLocation:self.placeLocation];
        
        // Copy NSObject subclasses
        [copy setTitle:[self.title copyWithZone:zone]];
        [copy setSubtitle:[self.subtitle copyWithZone:zone]];
        [copy setPlaceStation:self.placeStation];
    }
    
    return copy;
}

- (BOOL)isEqual:(id)object {
    if (self == object)
        return true;
    if ([self class] != [object class])
        return false;
    PlaceAnnotation *other = (PlaceAnnotation *)object;
    if (self.placeStation == nil) {
        if (other.placeStation != nil) {
            return false;
        }
    } else if (![self.placeStation isEqual:other.placeStation]) {
        return false;
    }
    return true;
}

- (NSUInteger)hash {
    const NSUInteger prime = 31;
    NSUInteger result = 1;
    result = prime * result + [self.placeStation hash];
    return result;
}

@end
