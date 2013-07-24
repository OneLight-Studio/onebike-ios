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

@interface MapController ()

@end

@implementation MapController {
    MKUserLocation *startUserLocation;
    WSRequest *_wsRequest;
    NSMutableArray *_stations;
    CLLocationCoordinate2D _northWestSpanCorner, _southEastSpanCorner;
    BOOL _isMapLoaded;
    //BOOL _searchViewVisible;
    BOOL _searching;
    CLLocation *_departureLocation;
    CLLocation *_arrivalLocation;
    NSTimer *_timer;
}

@synthesize mapView;
@synthesize searchView;
@synthesize departureField;
@synthesize arrivalField;
@synthesize bikeField;
@synthesize bikeStepper;
@synthesize searchButton;

# pragma mark Event

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEnterBackgroundNotificationReceived:) name:NOTIFICATION_DID_ENTER_BACKGROUND object:nil];
    NSLog(@"register on %@", NOTIFICATION_DID_ENTER_BACKGROUND);
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForegroundNotificationReceived:) name:NOTIFICATION_WILL_ENTER_FOREGROUND object:nil];
    NSLog(@"register on %@", NOTIFICATION_WILL_ENTER_FOREGROUND);

    self.mapView.delegate = self;
    self.mapView.showsUserLocation = YES;
    
    CGRect searchFrame = self.searchView.frame;
    searchFrame.origin.y = -searchFrame.size.height;
    self.searchView.frame = searchFrame;
    
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
        [self startTimer];
    }];
    
    NSLog(@"call ws");
    [_wsRequest call];
    
    self.mapView.showsUserLocation = YES;
    _isMapLoaded = false;
    
    // button bar init
    self.cancelButton = [[UIBarButtonItem alloc] initWithTitle:@"X" style:UIBarButtonItemStyleBordered target:self action:@selector(cancelSearchView:)];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    [self stopTimer];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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
    if (_isMapLoaded) {
        NSLog(@"region has changed");
        [self determineSpanCoordinates];
        [self displayStations];
    }
}

- (void)mapViewDidFinishLoadingMap:(MKMapView *)aMapView {
    NSLog(@"map is loaded");
    _isMapLoaded = true;
}

-(void)timerFired:(NSTimer *)theTimer
{
    NSLog(@"timer fired %@", [theTimer fireDate]);
    NSLog(@"call ws");
    [_wsRequest call];
}

- (void) didEnterBackgroundNotificationReceived:(NSNotification *)notification
{
    if ([[notification name] isEqualToString:NOTIFICATION_DID_ENTER_BACKGROUND]) {
        [self stopTimer];
    }
}

- (void) willEnterForegroundNotificationReceived:(NSNotification *)notification
{
    if ([[notification name] isEqualToString:NOTIFICATION_WILL_ENTER_FOREGROUND]) {
        double sleepingTime = [notification.object doubleValue];
        NSLog(@"sleeping time : %f s", sleepingTime);
        if (sleepingTime > TIME_BEFORE_REFRESH_DATA_IN_SECONDS) {
            NSLog(@"have to refresh stations data");
            NSLog(@"call ws");
            [_wsRequest call];
        }
    }
}

- (void) startTimer {
    if (_timer == nil)
    {
        NSLog(@"start timer");
        _timer = [NSTimer scheduledTimerWithTimeInterval:TIME_BEFORE_REFRESH_DATA_IN_SECONDS target:self selector:@selector(timerFired:) userInfo:nil repeats:YES];
    }
}

- (void) stopTimer {
    if (_timer != nil)
    {
        NSLog(@"stop timer");
        [_timer invalidate];
        _timer = nil;
    }
}

# pragma mark Map

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
    
    if (location.latitude >= _northWestSpanCorner.latitude && location.latitude <= _southEastSpanCorner.latitude
        && location.longitude >= _northWestSpanCorner.longitude && location.longitude <= _southEastSpanCorner.longitude
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
    _northWestSpanCorner.latitude  = center.latitude  - (region.span.latitudeDelta  / 2.0);
    _northWestSpanCorner.longitude = center.longitude - (region.span.longitudeDelta / 2.0);
    _southEastSpanCorner.latitude  = center.latitude  + (region.span.latitudeDelta  / 2.0);
    _southEastSpanCorner.longitude = center.longitude + (region.span.longitudeDelta / 2.0);
}

# pragma mark Navigation Bar

- (IBAction)displaySearchView:(id)sender {
    [self refreshNavigationBar:true];
    [UIView animateWithDuration:0.3 animations:^{
        CGRect searchFrame = self.searchView.frame;
        CGRect mapFrame = self.mapView.frame;
        searchFrame.origin.y = 0;
        mapFrame.origin.y = searchFrame.size.height;
        self.searchView.frame = searchFrame;
        self.mapView.frame = mapFrame;
    }];
}

- (void)cancelSearchView:(id)sender {
    [self refreshNavigationBar:false];
    [UIView animateWithDuration:0.3 animations:^{
        CGRect searchFrame = self.searchView.frame;
        CGRect mapFrame = self.mapView.frame;
        searchFrame.origin.y = -searchFrame.size.height;
        mapFrame.origin.y = 0;
        [self.view endEditing:YES];
        self.searchView.frame = searchFrame;
        self.mapView.frame = mapFrame;
    }];
}

- (void)refreshNavigationBar:(BOOL)isVisibleSearchView {
    
    if (isVisibleSearchView == false) {
        self.navigationItem.rightBarButtonItem = self.searchButton;
    } else {
        self.navigationItem.rightBarButtonItem = self.cancelButton;
    }
}

# pragma mark Search

- (IBAction)bikesChanged:(UIStepper *)stepper {
    // default min is 0 because we start with 0, now set the min to 1
    stepper.minimumValue = 1;
    self.bikeField.text = [NSString stringWithFormat:@"%d", (int) stepper.value];
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
        [self cancelSearchView:nil];
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
