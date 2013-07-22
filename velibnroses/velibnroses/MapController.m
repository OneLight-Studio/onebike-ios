//
//  MapController.m
//  velibnroses
//
//  Created by Thomas on 04/07/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import "MapController.h"
#import <CoreLocation/CoreLocation.h>
#import "Constants.h"
#import "WSRequest.h"
#import "Station.h"
#import "GeoUtils.h"

@implementation MapController {
    MKUserLocation *startUserLocation;
    WSRequest *_wsRequest;
    NSMutableArray *_stations;
    CLLocationCoordinate2D northWestSpanCorner, southEastCorner;
    BOOL isMapLoaded;
}

@synthesize mapView;

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.mapView.delegate = self;
    
    NSLog(@"init ws");
    _wsRequest = [[WSRequest alloc] initWithResource:JCD_WS_ENTRY_POINT_PARAM_VALUE inBackground:TRUE];
    //[_wsRequest appendParameterWithKey:JCD_CONTRACT_KEY_PARAM_NAME andValue:@"Toulouse"];
    [_wsRequest appendParameterWithKey:JCD_API_KEY_PARAM_NAME andValue:JCD_API_KEY_PARAM_VALUE];
    [_wsRequest handleResultWith:^(id json) {
        NSLog(@"ws result");
        _stations = (NSMutableArray *)[Station fromJSONArray:json];
        NSLog(@"stations count %i", _stations.count);
        [self determineSpanCoordinates];
        [self displayStations];
    }];
    
    NSLog(@"call ws");
    [_wsRequest call];
    
    self.mapView.showsUserLocation = YES;
    isMapLoaded = false;
}

- (void)viewWillAppear:(BOOL)animated
{
    // centered by default on Toulouse
    CLLocationCoordinate2D tls;
    tls.latitude = TLS_LAT;
    tls.longitude = TLS_LONG;
    
    MKCoordinateRegion viewRegion = MKCoordinateRegionMakeWithDistance(tls,
        SPAN_SIDE_INIT_LENGTH_IN_METERS, SPAN_SIDE_INIT_LENGTH_IN_METERS);
    [mapView setRegion:viewRegion animated:YES];
    NSLog(@"centered on Toulouse (%f,%f)", tls.latitude, tls.longitude);
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)mapView:(MKMapView *)aMapView didUpdateUserLocation:(MKUserLocation *)aUserLocation {
    if (startUserLocation == nil) {
        startUserLocation = aUserLocation;
        MKCoordinateRegion currentRegion = MKCoordinateRegionMakeWithDistance(aUserLocation.coordinate,
            SPAN_SIDE_INIT_LENGTH_IN_METERS, SPAN_SIDE_INIT_LENGTH_IN_METERS);
        [mapView setRegion:currentRegion animated:YES];
        NSLog(@"centered on user location (%f,%f)", aUserLocation.coordinate.latitude, aUserLocation.coordinate.longitude);
    }
}

- (void)mapView:(MKMapView *)aMapView regionDidChangeAnimated:(BOOL)animated {
    if (isMapLoaded) {
        NSLog(@"region has changed");
        [self determineSpanCoordinates];
        [self displayStations];
    }
}

- (void)mapViewDidFinishLoadingMap:(MKMapView *)aMapView {
    NSLog(@"map is loaded");
    isMapLoaded = true;
}

- (void)displayStations {
    if (_stations != nil) {
        NSLog(@"display stations");
        [mapView removeAnnotations:mapView.annotations];
        int invalidStations = 0;
        int displayedStations = 0;
        for (Station *station in _stations) {
            if (station.latitude != (id)[NSNull null] && station.longitude != (id)[NSNull null]) {
                
                CLLocationCoordinate2D coordinate;
                coordinate.latitude = [station.latitude doubleValue];
                coordinate.longitude = [station.longitude doubleValue];
                
                if ([self isVisibleLocation:coordinate]) {
                    NSMutableString *title = [NSMutableString stringWithFormat:@"nb vélos disponibles / nb places libres : %d", [station.availableBikes integerValue]];
                    [title appendFormat:@"/%d", [station.availableBikeStands integerValue]];
                    
                    MKPointAnnotation *marker = [[MKPointAnnotation alloc] init];
                    marker.coordinate = coordinate;
                    marker.title = station.name;
                    marker.subtitle = title;
                    
                    [mapView addAnnotation:marker];
                    
                    displayedStations++;
                }
            } else {
                NSLog(@"%@ : %@", station.name, station.contract);
                invalidStations++;
            }
        }
        NSLog(@"displayed stations count : %i", displayedStations);
        if (invalidStations > 0) {
            NSLog(@"invalid stations count : %i", invalidStations);
        }
    }
}

- (BOOL)isVisibleLocation:(CLLocationCoordinate2D)location {
    
    BOOL visible = false;
    
    CLLocationCoordinate2D userLocation = self.mapView.userLocation.coordinate;
    CLLocationCoordinate2D spanCenter = self.mapView.region.center;
    
    if (location.latitude >= northWestSpanCorner.latitude && location.latitude <= southEastCorner.latitude
        && location.longitude >= northWestSpanCorner.longitude && location.longitude <= southEastCorner.longitude
        && ([self unlessInMeters:SPAN_SIDE_MAX_LENGTH_IN_METERS from:userLocation for:location]
        || [self unlessInMeters:SPAN_SIDE_MAX_LENGTH_IN_METERS from:spanCenter for:location])) {
        visible = true;
    }
    
    return visible;
}
            
- (BOOL)unlessInMeters:(double)radius from:(CLLocationCoordinate2D)origin for:(CLLocationCoordinate2D)location {
    double dist = [GeoUtils getDistanceFromLat:origin.latitude toLat:location.latitude fromLong:origin.longitude toLong:location.longitude];
    //NSLog(@"distance from (%f,%f) for (%f,%f) : %f m", origin.latitude, origin.longitude, location.latitude, location.longitude, dist);
    return dist <= radius;
}

- (void)determineSpanCoordinates {
    MKCoordinateRegion region = self.mapView.region;
    CLLocationCoordinate2D center = region.center;
    NSLog(@"determine span coordinates");
    northWestSpanCorner.latitude  = center.latitude  - (region.span.latitudeDelta  / 2.0);
    northWestSpanCorner.longitude = center.longitude - (region.span.longitudeDelta / 2.0);
    southEastCorner.latitude  = center.latitude  + (region.span.latitudeDelta  / 2.0);
    southEastCorner.longitude = center.longitude + (region.span.longitudeDelta / 2.0);
}

@end
