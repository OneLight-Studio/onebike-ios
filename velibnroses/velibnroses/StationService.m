//
//  StationService.m
//  OneBike
//
//  Created by Sébastien BALARD on 28/10/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import "StationService.h"
#import "Constants.h"
#import "Station.h"
#import "GeoUtils.h"

@implementation StationService

- (NSMutableArray *)searchCloseStationsIn:(NSMutableArray *)contractStations forPlace:(Place *)aPlace withBikesNumber:(int)bikesNumber andMaxStationsNumber:(int)maxStationsNumber inARadiusOf:(int)maxRadius {
    NSLog(@"searching %d close stations around %f,%f", maxStationsNumber, aPlace.location.coordinate.latitude, aPlace.location.coordinate.longitude);
    int matchingStationNumber = 0;
    NSMutableArray *closeStations = [[NSMutableArray alloc] initWithCapacity:3];
    
    int radius = STATION_SEARCH_RADIUS_IN_METERS;
    while (matchingStationNumber < maxStationsNumber && radius <= maxRadius) {
        for (Station *station in contractStations) {
            if (matchingStationNumber < maxStationsNumber) {
                if (station.latitude != (id)[NSNull null] && station.longitude != (id)[NSNull null]) {
                    
                    CLLocationCoordinate2D stationCoordinate;
                    stationCoordinate.latitude = station.latitude.doubleValue;
                    stationCoordinate.longitude = station.longitude.doubleValue;
                    
                    if (![closeStations containsObject:station] && [GeoUtils unlessInMeters:radius fromOrigin:aPlace.location.coordinate forLocation:stationCoordinate]) {
                        if (station.availableBikes.integerValue >= bikesNumber) {
                            NSLog(@"close station found at %d m : %@ - %@ available bikes", radius, station.name, station.availableBikes);
                            [closeStations addObject:station];
                            matchingStationNumber++;
                        }
                    }
                }
            } else {
                // station max number is reached for this location
                break;
            }
        }
        radius += STATION_SEARCH_RADIUS_IN_METERS;
    }
    return closeStations;
}

- (NSMutableArray *)searchCloseStationsIn:(NSMutableArray *)contractStations forPlace:(Place *)aPlace withAvailableStandsNumber:(int)availableStandsNumber andMaxStationsNumber:(int)maxStationsNumber inARadiusOf:(int)maxRadius {
    NSLog(@"searching %d close stations around %f,%f", maxStationsNumber, aPlace.location.coordinate.latitude, aPlace.location.coordinate.longitude);
    int matchingStationNumber = 0;
    NSMutableArray *closeStations = [[NSMutableArray alloc] initWithCapacity:3];
    
    int radius = STATION_SEARCH_RADIUS_IN_METERS;
    while (matchingStationNumber < maxStationsNumber && radius <= maxRadius) {
        for (Station *station in contractStations) {
            if (matchingStationNumber < maxStationsNumber) {
                if (station.latitude != (id)[NSNull null] && station.longitude != (id)[NSNull null]) {
                    
                    CLLocationCoordinate2D stationCoordinate;
                    stationCoordinate.latitude = [station.latitude doubleValue];
                    stationCoordinate.longitude = [station.longitude doubleValue];
                    
                    if (![closeStations containsObject:station] && [GeoUtils unlessInMeters:radius fromOrigin:aPlace.location.coordinate forLocation:stationCoordinate]) {
                        if (station.availableBikeStands.integerValue >= availableStandsNumber) {
                            NSLog(@"close station found at %d m : %@ - %@ available stands", radius, station.name, station.availableBikeStands);
                            [closeStations addObject:station];
                            matchingStationNumber++;
                        }
                    }
                }
            } else {
                // station max number is reached for this location
                break;
            }
        }
        radius += STATION_SEARCH_RADIUS_IN_METERS;
    }
    return closeStations;
}

- (BOOL)isSameStationBetween:(Station *)first and:(Station *)second {
    return fabs(first.latitude.doubleValue - second.latitude.doubleValue) < 0.001 && fabs(first.longitude.doubleValue - second.longitude.doubleValue) < 0.001;
}

@end
