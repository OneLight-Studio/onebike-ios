//
//  MapController.m
//  velibnroses
//
//  Created by Thomas on 04/07/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import "MapController.h"
#import <CoreLocation/CoreLocation.h>

#define METERS_PER_MILE 1609.344
#define TLS_LAT 43.610477
#define TLS_LONG 1.443615
#define MIN_DIST_INTERVAL_IN_METER 50

@interface MapController ()

@end


@implementation MapController

@synthesize mapView;

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.mapView.showsUserLocation = YES;
    
    self.locationHelper = [[CoreLocationHelper alloc] init];
	self.locationHelper.delegate = self;
    self.locationHelper.locationManager.distanceFilter = MIN_DIST_INTERVAL_IN_METER;
    self.locationHelper.locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation;
    
    // centered by default on Toulouse
    currentLocation.latitude = TLS_LAT;
    currentLocation.longitude = TLS_LONG;
}

- (void)viewWillAppear:(BOOL)animated
{
    MKCoordinateRegion viewRegion = MKCoordinateRegionMakeWithDistance(currentLocation,
        10*METERS_PER_MILE, 10*METERS_PER_MILE);
    [mapView setRegion:viewRegion animated:YES];
    [self.locationHelper.locationManager startUpdatingLocation];
}

- (void)updateLocation:(CLLocation *)location {
    currentLocation.latitude = location.coordinate.latitude;
    currentLocation.longitude = location.coordinate.longitude;
    NSLog(@"(%f,%f)", location.coordinate.latitude, location.coordinate.longitude);
    MKCoordinateRegion viewRegion = MKCoordinateRegionMakeWithDistance(currentLocation,
        10*METERS_PER_MILE, 10*METERS_PER_MILE);
    [mapView setRegion:viewRegion animated:YES];
}

- (void)locationError:(NSError *)error {
    NSLog(@"update location problem %@", [error description]);
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
