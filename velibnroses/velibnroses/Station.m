//
//  Station.m
//  Velib N' Roses
//
//  Created by Sébastien BALARD on 16/07/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import "Station.h"

@implementation Station

@synthesize name, address, contract, latitude, longitude, banking, status, bikeStands, availableBikeStands, availableBikes;

+ (Station *)fromJSON:(id)json {
    if (json == (id)[NSNull null]) {
        return nil;
    }
    
    Station *station = [[Station alloc] init];
    station.name = [json valueForKey:@"name"];
    station.address = [json valueForKey:@"address"];
    station.contract = [json valueForKey:@"contract"];
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
        if (station != nil) {
            [array addObject:station];
        }
    }
    return array;
}

@end
