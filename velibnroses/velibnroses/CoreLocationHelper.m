//
//  CoreLocationHelper.m
//  Velib N' Roses
//
//  Created by Sébastien BALARD on 12/07/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import "CoreLocationHelper.h"
#import <CoreLocation/CoreLocation.h>

@implementation CoreLocationHelper

- (id)init {
    self = [super init];
	if (self != nil) {
		self.locationManager = [[CLLocationManager alloc] init];
		self.locationManager.delegate = self;
	}
	return self;
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    [self.delegate updateLocation:[locations lastObject]];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    [self.delegate locationError:error];
    [self.locationManager stopUpdatingLocation];
}

@end
