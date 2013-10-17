//
//  Station.m
//  Velib N' Roses
//
//  Created by Sébastien BALARD on 16/07/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import "Station.h"

@implementation Station

@synthesize name, address, latitude, longitude, banking, status, bikeStands, availableBikeStands, availableBikes;

//NSString *const StationTestName = @"TEST EDOS";

+ (Station *)fromJSON:(id)json {
    if (json == (id)[NSNull null]) {
        return nil;
    }
    
    Station *station = [[Station alloc] init];
    station.name = [json valueForKey:@"name"];
    station.address = [json valueForKey:@"address"];
    id lat = [[json objectForKey:@"position"] valueForKey:@"lat"];
    if (lat != (id)[NSNull null]) {
        station.latitude = [NSNumber numberWithDouble:[lat doubleValue]];
    }
    id lng = [[json objectForKey:@"position"] valueForKey:@"lng"];
    if (lng != (id)[NSNull null]) {
        station.longitude = [NSNumber numberWithDouble:[lng doubleValue]];
    }
    station.banking = [[json valueForKey:@"banking"] boolValue];
    if ([[json valueForKey:@"status"] isEqualToString:@"OPEN"]) {
        station.status = kOpen;
    } else {
        station.status = kClosed;
    }
    station.bikeStands = [NSNumber numberWithDouble:[[json valueForKey:@"bike_stands"] doubleValue]];
    station.availableBikeStands = [NSNumber numberWithDouble:[[json valueForKey:@"available_bike_stands"] doubleValue]];
    station.availableBikes = [NSNumber numberWithDouble:[[json valueForKey:@"available_bikes"] doubleValue]];
    
    return station;
}

+ (NSArray *)fromJSONArray:(id)json {
    NSMutableArray *array = [NSMutableArray array];
    for (id jsonObject in json) {
        Station *station = [self fromJSON:jsonObject];
        // don't add test stations or station with latlng = (0,0), TODO remove: unuseful now because we think in contract term now
        if (station != nil/* && (station.latitude.doubleValue != 0 || station.longitude.doubleValue != 0) && ![station.name isEqualToString:StationTestName]*/) {
            [array addObject:station];
        }
    }
    return array;
}

- (CLLocationCoordinate2D) coordinate {
    CLLocationCoordinate2D cc2d;
    cc2d.latitude = self.latitude.doubleValue;
    cc2d.longitude = self.longitude.doubleValue;
    return cc2d;
}

- (id)copyWithZone:(NSZone *)zone
{
    id copy = [[[self class] alloc] init];
    if (copy) {
        // Set primitives
        [copy setBanking:self.banking];
        [copy setStatus:self.status];
        
        // Copy NSObject subclasses
        [copy setName:[self.name copyWithZone:zone]];
        [copy setAddress:[self.address copyWithZone:zone]];
        [copy setLatitude:[self.latitude copyWithZone:zone]];
        [copy setLongitude:[self.longitude copyWithZone:zone]];
        [copy setBikeStands:[self.bikeStands copyWithZone:zone]];
        [copy setAvailableBikeStands:[self.availableBikeStands copyWithZone:zone]];
        [copy setAvailableBikes:[self.availableBikes copyWithZone:zone]];
    }
    
    return copy;
}

- (BOOL)isEqual:(id)object {
    if (self == object)
        return true;
    if ([self class] != [object class])
        return false;
    Station *other = (Station *)object;
    if (latitude == nil) {
        if (other.latitude != nil) {
            return false;
        }
    } else if (longitude == nil) {
        if (other.longitude != nil) {
            return false;
        }
    } else if (![latitude isEqual:other.latitude]) {
        return false;
    } else if (![longitude isEqual:other.longitude]) {
        return false;
    }
    return true;
}

- (NSUInteger)hash {
    const NSUInteger prime = 31;
    NSUInteger result = 1;
    result = prime * result + [latitude hash];
    result = prime * result + [longitude hash];
    return result;
}

@end
