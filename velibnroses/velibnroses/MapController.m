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
    CLLocationCoordinate2D northWestCorner, southEastCorner;
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
    }];
    
    NSLog(@"call ws");
    [_wsRequest call];
    
    self.mapView.showsUserLocation = YES;
}

- (void)viewWillAppear:(BOOL)animated
{
    // centered by default on Toulouse
    CLLocationCoordinate2D tls;
    tls.latitude = TLS_LAT;
    tls.longitude = TLS_LONG;
    
    MKCoordinateRegion viewRegion = MKCoordinateRegionMakeWithDistance(tls,
        ZOOM_SQUARE_SIDE_IN_KM, ZOOM_SQUARE_SIDE_IN_KM);
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
            ZOOM_SQUARE_SIDE_IN_KM, ZOOM_SQUARE_SIDE_IN_KM);
        [mapView setRegion:currentRegion animated:YES];
        NSLog(@"centered on user location (%f,%f)", aUserLocation.coordinate.latitude, aUserLocation.coordinate.longitude);
    }
}

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
    [self determineSpanCoordinates];
    [self displayStations];
}

- (void)mapViewDidFinishLoadingMap:(MKMapView *)mapView {
    [self determineSpanCoordinates];
    [self displayStations];
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
                
                if ([self isRenderableLocation:coordinate]) {
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

- (BOOL)isRenderableLocation:(CLLocationCoordinate2D) location {
    
    BOOL renderable = false;
    
    if (location.latitude  >= northWestCorner.latitude && location.latitude  <= southEastCorner.latitude
        && location.longitude >= northWestCorner.longitude && location.longitude <= southEastCorner.longitude) {
        //NSLog(@"(%f,%f) is in visible span", location.latitude, location.longitude);
        renderable = true;
    }
    
    return renderable;
}

- (void)determineSpanCoordinates {
    MKCoordinateRegion region = self.mapView.region;
    CLLocationCoordinate2D center   = region.center;
    NSLog(@"determine span coordinates");
    northWestCorner.latitude  = center.latitude  - (region.span.latitudeDelta  / 2.0);
    northWestCorner.longitude = center.longitude - (region.span.longitudeDelta / 2.0);
    southEastCorner.latitude  = center.latitude  + (region.span.latitudeDelta  / 2.0);
    southEastCorner.longitude = center.longitude + (region.span.longitudeDelta / 2.0);
}

@end
