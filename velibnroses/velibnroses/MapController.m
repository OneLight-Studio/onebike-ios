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


@implementation MapController {
    BOOL _searchViewVisible;
    BOOL _searching;
    CLLocation *_departureLocation;
    CLLocation *_arrivalLocation;
}

@synthesize mapView;
@synthesize searchView;
@synthesize departureField;
@synthesize arrivalField;
@synthesize bikeField;
@synthesize bikeStepper;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.mapView.showsUserLocation = YES;
    _searchViewVisible = NO;
    
    CGRect searchFrame = self.searchView.frame;
    CGRect mapFrame = self.mapView.frame;
    searchFrame.origin.y = -searchFrame.size.height;
    mapFrame.origin.y = 0;
    self.searchView.frame = searchFrame;
    self.mapView.frame = mapFrame;
    
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

- (IBAction)bikesChanged:(UIStepper *)stepper {
    // default min is 0 because we start with 0, now set the min to 1
    stepper.minimumValue = 1;
    self.bikeField.text = [NSString stringWithFormat:@"%d", (int) stepper.value];
}

- (IBAction)toggleSearchView:(id)sender {
    [self toggleSearchView];
}

- (IBAction)useMyLocationAsDeparture:(id)sender {
    CLLocationCoordinate2D userLocation = self.mapView.userLocation.coordinate;
    CLLocation *location = [[CLLocation alloc] initWithLatitude:userLocation.latitude longitude:userLocation.longitude];
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    [geocoder reverseGeocodeLocation:location completionHandler:^(NSArray *placemarks, NSError *error) {
        if (error != nil) {
            self.departureField.text = [NSString stringWithFormat:@"%f,%f", userLocation.latitude, userLocation.longitude];
        } else {
            self.departureField.text = [[[(CLPlacemark *)[placemarks objectAtIndex:0] addressDictionary] valueForKey:@"FormattedAddressLines"] componentsJoinedByString:@", "];
        }
    }];
}

- (IBAction)useMyLocationAsArrival:(id)sender {
    CLLocationCoordinate2D userLocation = self.mapView.userLocation.coordinate;
    CLLocation *location = [[CLLocation alloc] initWithLatitude:userLocation.latitude longitude:userLocation.longitude];
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    [geocoder reverseGeocodeLocation:location completionHandler:^(NSArray *placemarks, NSError *error) {
        if (error != nil) {
            self.arrivalField.text = [NSString stringWithFormat:@"%f,%f", userLocation.latitude, userLocation.longitude];
        } else {
            self.arrivalField.text = [[[(CLPlacemark *)[placemarks objectAtIndex:0] addressDictionary] valueForKey:@"FormattedAddressLines"] componentsJoinedByString:@", "];
        }
    }];
}

- (IBAction)search:(id)sender {
    [self.view endEditing:YES];
    if (self.departureField.text.length == 0) {
        [[[UIAlertView alloc] initWithTitle:nil message:NSLocalizedString(@"missing_departure", @"") delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil] show];
    } else if (self.arrivalField.text.length == 0) {
        [[[UIAlertView alloc] initWithTitle:nil message:NSLocalizedString(@"missing_arrival", @"") delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil] show];
    } else if (self.bikeField.text.length == 0 || [self.bikeField.text intValue] <= 0) {
        [self.view endEditing:YES];
        [[[UIAlertView alloc] initWithTitle:nil message:NSLocalizedString(@"missing_bikes", @"") delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil] show];
    } else {
        [self.view endEditing:YES];
        [self toggleSearchView];
        _departureLocation = nil;
        _arrivalLocation = nil;
        _searching = YES;
        [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
        CLGeocoder *departureGeocoder = [[CLGeocoder alloc] init];
        CLGeocoder *arrivalGeocoder = [[CLGeocoder alloc] init];
        [departureGeocoder geocodeAddressString:self.departureField.text inRegion:nil completionHandler:^(NSArray *placemarks, NSError *error) {
            if (_searching) {
                if (error != nil) {
                    _searching = NO;
                    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                    [[[UIAlertView alloc] initWithTitle:nil message:NSLocalizedString(@"departure_not_found", @"") delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil] show];
                } else {
                    _departureLocation = [[placemarks objectAtIndex:0] location];
                    if (_arrivalLocation != nil) {
                        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                        [self searchWithDeparture:_departureLocation andArrival:_arrivalLocation withNumberOfBikes:[self.bikeField.text intValue]];
                    }
                }
            }
        }];
        [arrivalGeocoder geocodeAddressString:self.arrivalField.text inRegion:nil completionHandler:^(NSArray *placemarks, NSError *error) {
            if (_searching) {
                if (error != nil) {
                    _searching = NO;
                    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                    [[[UIAlertView alloc] initWithTitle:nil message:NSLocalizedString(@"arrival_not_found", @"") delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil] show];
                } else {
                    _arrivalLocation = [[placemarks objectAtIndex:0] location];
                    if (_departureLocation != nil) {
                        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                        [self searchWithDeparture:_departureLocation andArrival:_arrivalLocation withNumberOfBikes:[self.bikeField.text intValue]];
                    }
                }
            }
        }];
    }
}

- (void)toggleSearchView {
    _searchViewVisible = !_searchViewVisible;
    [UIView animateWithDuration:0.3 animations:^{
        CGRect searchFrame = self.searchView.frame;
        CGRect mapFrame = self.mapView.frame;
        if (_searchViewVisible) {
            searchFrame.origin.y = 0;
            mapFrame.origin.y = searchFrame.size.height;
        } else {
            searchFrame.origin.y = -searchFrame.size.height;
            mapFrame.origin.y = 0;
            [self.view endEditing:YES];
        }
        self.searchView.frame = searchFrame;
        self.mapView.frame = mapFrame;
    }];
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    if (textField == self.bikeField) {
        [self.view endEditing:YES];
        return NO;
    }
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.departureField) {
        [self.arrivalField becomeFirstResponder];
    } else if (textField == self.arrivalField) {
        [self.view endEditing:YES];
    }
    return YES;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [self.view endEditing:YES];
}

- (void)searchWithDeparture:(CLLocation *)departure andArrival:(CLLocation *)arrival withNumberOfBikes:(int)bikes {
    NSLog(@"%f,%f -> %f,%f (%d)", departure.coordinate.latitude, departure.coordinate.longitude, arrival.coordinate.latitude, arrival.coordinate.longitude, bikes);
    // TODO Search stations
}

@end
