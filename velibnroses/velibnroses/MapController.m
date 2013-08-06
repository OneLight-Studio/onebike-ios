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
#import "RoutePolyline.h"

@interface MapController ()
    
@end

@implementation MapController {
    MKUserLocation *startUserLocation;
    WSRequest *_wsRequest;
    NSMutableArray *_stations;
    CLLocationCoordinate2D _northWestSpanCorner, _southEastSpanCorner;
    BOOL _isMapLoaded;
    BOOL _searching;
    CLLocation *_departureLocation;
    CLLocation *_arrivalLocation;
    NSTimer *_timer;
    RoutePolyline *_route;
    int _mapViewState;
    BOOL _isSearchViewVisible;
    NSMutableArray *_routeCloseStations;
    NSInteger _closeStationsAroundDepartureNumber;
    NSInteger _closeStationsAroundArrivalNumber;
    Station *_departureStation;
    Station *_arrivalStation;
}

@synthesize mapView;
@synthesize searchView;
@synthesize departureField;
@synthesize arrivalField;
@synthesize bikeField;
@synthesize bikeStepper;
@synthesize radiusField;
@synthesize radiusStepper;
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
        if (_mapViewState == MAP_VIEW_DEFAULT_STATE) {
            [self determineSpanCoordinates];
            [self displayStations];
        }
        [self startTimer];
    }];
    
    NSLog(@"call ws");
    [_wsRequest call];
    
    self.mapView.showsUserLocation = YES;
    _isMapLoaded = false;
    _mapViewState = MAP_VIEW_DEFAULT_STATE;
    _isSearchViewVisible = false;
    self.bikeField.text = @"1";
    self.radiusField.text = @"1000";
    
    // button bar init
    self.cancelButton = [[UIBarButtonItem alloc] initWithTitle:@"X" style:UIBarButtonItemStyleBordered target:self action:@selector(cancelButtonCallBack:)];
    
    _routeCloseStations = [[NSMutableArray alloc] init];
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
        [self centerMapViewOnUserLocation];
    }
}

- (void)mapView:(MKMapView *)aMapView regionDidChangeAnimated:(BOOL)animated {
    if (_isMapLoaded && _mapViewState == MAP_VIEW_DEFAULT_STATE) {
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

# pragma mark -
# pragma mark Navigation Bar

- (IBAction)displaySearchView:(id)sender {
    _isSearchViewVisible = true;
    [self refreshNavigationBarWithSearchView:_isSearchViewVisible withRideView:_mapViewState == MAP_VIEW_SEARCH_STATE];
    [UIView animateWithDuration:0.3 animations:^{
        CGRect searchFrame = self.searchView.frame;
        CGRect mapFrame = self.mapView.frame;
        searchFrame.origin.y = 0;
        mapFrame.origin.y = searchFrame.size.height;
        self.searchView.frame = searchFrame;
        self.mapView.frame = mapFrame;
    }];
}

- (void)cancelButtonCallBack:(id)sender {
    if (_isSearchViewVisible) {
        _isSearchViewVisible = false;
        [UIView animateWithDuration:0.3 animations:^{
            CGRect searchFrame = self.searchView.frame;
            CGRect mapFrame = self.mapView.frame;
            searchFrame.origin.y = -searchFrame.size.height;
            mapFrame.origin.y = 0;
            [self.view endEditing:YES];
            self.searchView.frame = searchFrame;
            self.mapView.frame = mapFrame;
        }];
    } else {
        _mapViewState = MAP_VIEW_DEFAULT_STATE;
        [self resetSearchViewFields];
        [self removeRoute];
        [self centerMapViewOnUserLocation];
        [self displayStations];
    }
    [self refreshNavigationBarWithSearchView:_isSearchViewVisible withRideView:_mapViewState == MAP_VIEW_SEARCH_STATE];
}

- (void)refreshNavigationBarWithSearchView:(BOOL)hasSearchView withRideView:(BOOL)hasRideView {
    
    if (hasSearchView == false) {
        if (hasRideView == false) {
            self.navigationItem.rightBarButtonItems = nil;
            self.navigationItem.rightBarButtonItem = self.searchButton;
        } else {
            self.navigationItem.rightBarButtonItem = nil;
            self.navigationItem.rightBarButtonItems = @[self.cancelButton,self.searchButton];
        }
    } else {
        self.navigationItem.rightBarButtonItems = nil;
        self.navigationItem.rightBarButtonItem = self.cancelButton;
    }
}

# pragma mark Map View

- (void)centerMapViewOnUserLocation {
    MKCoordinateRegion currentRegion = MKCoordinateRegionMakeWithDistance(startUserLocation.coordinate, SPAN_SIDE_INIT_LENGTH_IN_METERS, SPAN_SIDE_INIT_LENGTH_IN_METERS);
    [mapView setRegion:currentRegion animated:YES];
    NSLog(@"centered on user location (%f,%f)", startUserLocation.coordinate.latitude, startUserLocation.coordinate.longitude);
}

- (void)displayStations {
    if (_stations != nil) {
        NSLog(@"display stations");
        [mapView removeAnnotations:mapView.annotations];
        int invalidStations = 0;
        int displayedStations = 0;
        for (Station *station in _stations) {
            if (station.latitude != (id)[NSNull null] && station.longitude != (id)[NSNull null]) {
                if ([self isVisibleStation:station]) {
                    [mapView addAnnotation:[self createStationAnnotation:station]];
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

- (MKPointAnnotation *)createStationAnnotation:(Station *)station {
    
    CLLocationCoordinate2D stationCoordinate;
    stationCoordinate.latitude = [station.latitude doubleValue];
    stationCoordinate.longitude = [station.longitude doubleValue];
    
    NSMutableString *title = [NSMutableString stringWithFormat:@"nb vélos disponibles / nb places libres : %d", [station.availableBikes integerValue]];
    [title appendFormat:@"/%d", [station.availableBikeStands integerValue]];
    
    MKPointAnnotation *marker = [[MKPointAnnotation alloc] init];
    marker.coordinate = stationCoordinate;
    marker.title = station.name;
    marker.subtitle = title;
    return marker;
}

- (BOOL)isVisibleStation:(Station *)station {
    
    BOOL visible = false;
    
    CLLocationCoordinate2D stationCoordinate;
    stationCoordinate.latitude = [station.latitude doubleValue];
    stationCoordinate.longitude = [station.longitude doubleValue];
    
    CLLocationCoordinate2D userLocation = self.mapView.userLocation.coordinate;
    CLLocationCoordinate2D spanCenter = self.mapView.region.center;
    
    if (stationCoordinate.latitude >= _northWestSpanCorner.latitude && stationCoordinate.latitude <= _southEastSpanCorner.latitude
        && stationCoordinate.longitude >= _northWestSpanCorner.longitude && stationCoordinate.longitude <= _southEastSpanCorner.longitude
        && ([self unlessInMeters:SPAN_SIDE_MAX_LENGTH_IN_METERS from:userLocation for:stationCoordinate]
            || [self unlessInMeters:SPAN_SIDE_MAX_LENGTH_IN_METERS from:spanCenter for:stationCoordinate])) {
            visible = true;
        }
    
    return visible;
}

- (BOOL)unlessInMeters:(double)radius from:(CLLocationCoordinate2D)origin for:(CLLocationCoordinate2D)location {
    double dist = [GeoUtils getDistanceFromLat:origin.latitude toLat:location.latitude fromLong:origin.longitude toLong:location.longitude];
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

-(MKOverlayView *)mapView:(MKMapView *)aMapView viewForOverlay:(id<MKOverlay>)overlay
{
    NSLog(@"render route");
    RoutePolyline *polyline = overlay;
    MKPolylineView *polylineView = [[MKPolylineView alloc] initWithPolyline:polyline.polyline];
    polylineView.lineWidth = 5;
    polylineView.strokeColor = [UIColor blackColor];
    return polylineView;
}

- (MKAnnotationView *)mapView:(MKMapView *)aMapView viewForAnnotation:(id <MKAnnotation>)annotation
{
    MKPinAnnotationView *annotationView;
    if (annotation != mapView.userLocation) {
        static NSString *annotationID = @"pinView";
        annotationView = (MKPinAnnotationView *)[aMapView dequeueReusableAnnotationViewWithIdentifier:annotationID];
        if (annotationView == nil) {
            annotationView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:annotationID];
        }
        if ([annotation isKindOfClass:[MKPointAnnotation class]]) {
            MKPointAnnotation *marker = annotation;
            if ([marker.title isEqualToString:@"departure"]) {
                NSLog(@"render departure pin");
                annotationView.pinColor = MKPinAnnotationColorGreen;
            } else if ([marker.title isEqualToString:@"arrival"]) {
                NSLog(@"render arrival pin");
                annotationView.pinColor = MKPinAnnotationColorPurple;
            } else {
                annotationView.pinColor = MKPinAnnotationColorRed;
            }
        }
        annotationView.canShowCallout = YES;
    }
    return annotationView;
}

# pragma mark Search View

- (IBAction)bikesChanged:(UIStepper *)stepper {
    self.bikeField.text = [NSString stringWithFormat:@"%d", (int) stepper.value];
}

- (IBAction)radiusChanged:(UIStepper *)stepper {
    self.radiusField.text = [NSString stringWithFormat:@"%d", (int) stepper.value];
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
    } else {
        [self.view endEditing:YES];
        [self cancelButtonCallBack:nil];
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
                        [self searchWithDeparture:_departureLocation andArrival:_arrivalLocation withNumberOfBikes:[self.bikeField.text intValue] inARadiusOf:[self.radiusField.text intValue]];
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
                        [self searchWithDeparture:_departureLocation andArrival:_arrivalLocation withNumberOfBikes:[self.bikeField.text intValue] inARadiusOf:[self.radiusField.text intValue]];
                    }
                }
            }
        }];
    }
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    if (textField == self.bikeField || textField == self.radiusField) {
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

- (void)resetSearchViewFields {
    self.departureField.text = nil;
    self.arrivalField.text = nil;
    self.bikeField.text = @"1";
    self.radiusField.text = @"1000";
    
    _departureLocation = nil;
    _departureStation = nil;
    _arrivalLocation = nil;
    _arrivalStation = nil;
}

- (void)searchWithDeparture:(CLLocation *)departure andArrival:(CLLocation *)arrival withNumberOfBikes:(int)bikes inARadiusOf:(int)radius {
    NSLog(@"%f,%f -> %f,%f (%d)", departure.coordinate.latitude, departure.coordinate.longitude, arrival.coordinate.latitude, arrival.coordinate.longitude, bikes);
    _mapViewState = MAP_VIEW_SEARCH_STATE;
    [self refreshNavigationBarWithSearchView:_isSearchViewVisible withRideView:_mapViewState == MAP_VIEW_SEARCH_STATE];
    [_routeCloseStations removeAllObjects];
    [self removeRoute];
    _departureStation = nil;
    _arrivalStation = nil;
    [mapView removeAnnotations:mapView.annotations];
    _closeStationsAroundDepartureNumber = [self searchCloseStationsAround:departure isArrival:false withNumberOfBikes:bikes andStationNumber:3 inARadiusOf:radius];
    _closeStationsAroundArrivalNumber = [self searchCloseStationsAround:arrival isArrival:true withNumberOfBikes:bikes andStationNumber:3 inARadiusOf:radius];
    [self displayCloseStations];
    if (_departureStation != nil && _arrivalStation != nil) {
      [self findAndDrawRouteFromDeparture:_departureStation toArrival:_arrivalStation];
    }
}

# pragma mark -
# pragma mark Search utils

- (int)searchCloseStationsAround:(CLLocation *)location isArrival:(BOOL)arrival withNumberOfBikes:(int)bikes andStationNumber:(int)number inARadiusOf:(int)maxRadius {
    NSLog(@"searching close stations");
    int matchingStationNumber = 0;
    
    int radius = STATION_SEARCH_RADIUS_IN_METERS;
    while (matchingStationNumber < number && radius <= maxRadius) {
        for (Station *station in _stations) {
            if (matchingStationNumber < number) {
                if (station.latitude != (id)[NSNull null] && station.longitude != (id)[NSNull null]) {
                    
                    CLLocationCoordinate2D stationCoordinate;
                    stationCoordinate.latitude = [station.latitude doubleValue];
                    stationCoordinate.longitude = [station.longitude doubleValue];
                    
                    if (![_routeCloseStations containsObject:station] && [self unlessInMeters:radius from:location.coordinate for:stationCoordinate]) {
                        if (!arrival && [station.availableBikes integerValue] >= bikes) {
                            NSLog(@"close station found at %d m : %@ - %@ vélos dispos", radius, station.name, station.availableBikes);
                            [_routeCloseStations addObject:station];
                            if (_departureStation == nil) {
                                _departureStation = station;
                            }
                            matchingStationNumber++;
                        } else if (arrival && [station.availableBikeStands integerValue] >= bikes) {
                            NSLog(@"close station found at %d m : %@ - %@ bornes dispos", radius, station.name, station.availableBikeStands);
                            [_routeCloseStations addObject:station];
                            if (_arrivalStation == nil) {
                                _arrivalStation = station;
                            }
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
    return matchingStationNumber;
}

- (void)displayCloseStations {
    if ([_routeCloseStations count] == 0 || _closeStationsAroundDepartureNumber == 0 || _closeStationsAroundArrivalNumber == 0) {
        [[[UIAlertView alloc] initWithTitle:nil message:NSLocalizedString(@"incomplete_search_result", @"") delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil] show];
    }
    // departure annotation
    MKPointAnnotation *marker = [[MKPointAnnotation alloc] init];
    marker.coordinate = _departureLocation.coordinate;
    marker.title = @"departure";
    
    [mapView addAnnotation:marker];
    
    // arrival annotation
    marker = [[MKPointAnnotation alloc] init];
    marker.coordinate = _arrivalLocation.coordinate;
    marker.title = @"arrival";
    
    [mapView addAnnotation:marker];
    
    for (Station *station in _routeCloseStations) {
        [mapView addAnnotation:[self createStationAnnotation:station]];
    }
}

- (void)removeRoute {
    if (_route != nil) {
        [mapView removeOverlay:_route];
        _route = nil;
    }
}

- (void)findAndDrawRouteFromDeparture:(Station *)departure toArrival:(Station *)arrival {
    
    NSLog(@"searching for a route");
    WSRequest *googleRequest = [[WSRequest alloc] initWithResource:@"https://maps.googleapis.com/maps/api/directions/json" inBackground:NO];
    [googleRequest appendParameterWithKey:@"origin" andValue:[NSString stringWithFormat:@"%@,%@", departure.latitude, departure.longitude]];
    [googleRequest appendParameterWithKey:@"destination" andValue:[NSString stringWithFormat:@"%@,%@", arrival.latitude, arrival.longitude]];
    [googleRequest appendParameterWithKey:@"language" andValue:[[NSLocale currentLocale] objectForKey:NSLocaleCountryCode]];
    [googleRequest appendParameterWithKey:@"mode" andValue:@"walking"];
    [googleRequest appendParameterWithKey:@"sensor" andValue:@"true"];
    [googleRequest handleResultWith:^(id json) {
        NSString *status = [json valueForKey:@"status"];
        
        if ([status isEqualToString:@"OK"]) {
            NSLog(@"find a route");
            
            NSString *encodedPolyline = [[[[json objectForKey:@"routes"] firstObject] objectForKey:@"overview_polyline"] valueForKey:@"points"];
            _route = [RoutePolyline routePolylineFromPolyline:[GeoUtils polylineWithEncodedString:encodedPolyline]];
            [mapView addOverlay:_route];
            [mapView setVisibleMapRect:_route.boundingMapRect animated:YES];
            
        } else {
            NSLog(@"Google Maps API error %@", status);
            [[[UIAlertView alloc] initWithTitle:@"error" message:@"Google Maps API error" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
        }
    }];
    [googleRequest handleErrorWith:^(int errorCode) {
        NSLog(@"HTTP error %d", errorCode);
        [[[UIAlertView alloc] initWithTitle:@"error" message:@"HTTP error" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
    }];
    [googleRequest handleExceptionWith:^(NSError *exception) {
        NSLog(@"Exception %@", exception.debugDescription);
        [[[UIAlertView alloc] initWithTitle:@"error" message:@"Exception" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
    }];
    [googleRequest call];
}

@end
