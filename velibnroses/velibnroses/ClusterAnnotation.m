//
//  ClusterAnnotation.m
//  OneBike
//
//  Created by Sébastien BALARD on 16/09/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import "ClusterAnnotation.h"

@implementation ClusterAnnotation

@synthesize region;

- (BOOL)isEqual:(id)object {
    if (self == object)
        return true;
    if ([self class] != [object class])
        return false;
    ClusterAnnotation *other = (ClusterAnnotation *)object;
    if ([[NSNumber alloc] initWithDouble:self.coordinate.latitude] == nil) {
        if ([[NSNumber alloc] initWithDouble:other.coordinate.latitude] != nil) {
            return false;
        }
    } else if ([[NSNumber alloc] initWithDouble:self.coordinate.longitude] == nil) {
        if ([[NSNumber alloc] initWithDouble:other.coordinate.longitude] != nil) {
            return false;
        }
    } else if (![[[NSNumber alloc] initWithDouble:self.coordinate.latitude] isEqual:[[NSNumber alloc] initWithDouble:other.coordinate.latitude]]) {
        return false;
    } else if (![[[NSNumber alloc] initWithDouble:self.coordinate.longitude] isEqual:[[NSNumber alloc] initWithDouble:other.coordinate.longitude]]) {
        return false;
    }
    return true;
}

- (NSUInteger)hash {
    const NSUInteger prime = 31;
    NSUInteger result = 1;
    result = prime * result + [[[NSNumber alloc] initWithDouble:self.coordinate.latitude] hash];
    result = prime * result + [[[NSNumber alloc] initWithDouble:self.coordinate.longitude] hash];
    return result;
}

@end
