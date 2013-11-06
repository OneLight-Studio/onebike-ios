//
//  Place.m
//  OneBike
//
//  Created by Sébastien BALARD on 25/10/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import "Place.h"

@implementation Place

- (BOOL)isEqual:(id)object {
    if (self == object)
        return true;
    if ([self class] != [object class])
        return false;
    Place *other = (Place *)object;
    if (self.location == nil) {
        if (other.location != nil) {
            return false;
        }
    } else if (self.contract == nil) {
        if (other.contract != nil) {
            return false;
        }
    } else if (![self.location isEqual:other.location]) {
        return false;
    } else if (![self.contract isEqual:other.contract]) {
        return false;
    }
    return true;
}

- (NSUInteger)hash {
    const NSUInteger prime = 31;
    NSUInteger result = 1;
    result = prime * result + [self.location hash];
    result = prime * result + [self.contract hash];
    return result;
}

@end
