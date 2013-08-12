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
    int _jcdRequestAttemptsNumber;
}

@synthesize mapPanel;
@synthesize searchPanel;
@synthesize departureField;
@synthesize arrivalField;
@synthesize bikeField;
@synthesize bikeStepper;
@synthesize radiusField;
@synthesize radiusStepper;
@synthesize searchBarButton;
@synthesize searchButton;

# pragma mark -

- (void)registerOn
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEnterBackgroundNotificationReceived:) name:NOTIFICATION_DID_ENTER_BACKGROUND object:nil];
    NSLog(@"register on %@", NOTIFICATION_DID_ENTER_BACKGROUND);
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForegroundNotificationReceived:) name:NOTIFICATION_WILL_ENTER_FOREGROUND object:nil];
    NSLog(@"register on %@", NOTIFICATION_WILL_ENTER_FOREGROUND);
}

- (void)initView
{
    self.mapPanel.delegate = self;
    self.mapPanel.showsUserLocation = YES;
    
    CGRect searchFrame = self.searchPanel.frame;
    searchFrame.origin.y = -searchFrame.size.height;
    self.searchPanel.frame = searchFrame;
    self.bikeField.text = @"1";
    self.standField.text = @"1";
    self.radiusField.text = @"1000";
    self.cancelBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"Images/NavigationBar/NBClose"] style:UIBarButtonItemStyleBordered target:self action:@selector(cancelBarButtonClicked:)];
    
    _isMapLoaded = false;
    _mapViewState = MAP_VIEW_DEFAULT_STATE;
    _isSearchViewVisible = false;
    
    [self.searchBarButton setBackgroundImage:[UIImage new] forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    [self.cancelBarButton setBackgroundImage:[UIImage new] forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    
    [self.bikeStepper setBackgroundImage:[UIImage new] forState:UIControlStateNormal];
    [self.bikeStepper setBackgroundImage:[UIImage new] forState:UIControlStateDisabled];
    [self.bikeStepper setBackgroundImage:[UIImage new] forState:UIControlStateHighlighted];
    [self.bikeStepper setBackgroundImage:[UIImage new] forState:UIControlStateSelected];
    [self.bikeStepper setDividerImage:[UIImage new] forLeftSegmentState:UIControlStateNormal rightSegmentState:UIControlStateNormal];
    [self.bikeStepper setIncrementImage:[UIImage imageNamed:@"Images/SearchPanel/SPStepperIncrement"] forState:UIControlStateNormal];
    [self.bikeStepper setDecrementImage:[UIImage imageNamed:@"Images/SearchPanel/SPStepperDecrement"] forState:UIControlStateNormal];
    [self.standStepper setBackgroundImage:[UIImage new] forState:UIControlStateNormal];
    [self.standStepper setBackgroundImage:[UIImage new] forState:UIControlStateDisabled];
    [self.standStepper setBackgroundImage:[UIImage new] forState:UIControlStateHighlighted];
    [self.standStepper setBackgroundImage:[UIImage new] forState:UIControlStateSelected];
    [self.standStepper setDividerImage:[UIImage new] forLeftSegmentState:UIControlStateNormal rightSegmentState:UIControlStateNormal];
    [self.standStepper setIncrementImage:[UIImage imageNamed:@"Images/SearchPanel/SPStepperIncrement"] forState:UIControlStateNormal];
    [self.standStepper setDecrementImage:[UIImage imageNamed:@"Images/SearchPanel/SPStepperDecrement"] forState:UIControlStateNormal];
    [self.radiusStepper setBackgroundImage:[UIImage new] forState:UIControlStateNormal];
    [self.radiusStepper setBackgroundImage:[UIImage new] forState:UIControlStateDisabled];
    [self.radiusStepper setBackgroundImage:[UIImage new] forState:UIControlStateHighlighted];
    [self.radiusStepper setBackgroundImage:[UIImage new] forState:UIControlStateSelected];
    [self.radiusStepper setDividerImage:[UIImage new] forLeftSegmentState:UIControlStateNormal rightSegmentState:UIControlStateNormal];
    [self.radiusStepper setIncrementImage:[UIImage imageNamed:@"Images/SearchPanel/SPStepperIncrement"] forState:UIControlStateNormal];
    [self.radiusStepper setDecrementImage:[UIImage imageNamed:@"Images/SearchPanel/SPStepperDecrement"] forState:UIControlStateNormal];
    
    _routeCloseStations = [[NSMutableArray alloc] init];
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

# pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self registerOn];
    [self initView];
    
    _jcdRequestAttemptsNumber = 0;
    NSLog(@"init jcd ws");
    _wsRequest = [[WSRequest alloc] initWithResource:JCD_WS_ENTRY_POINT_PARAM_VALUE inBackground:TRUE];
    [_wsRequest appendParameterWithKey:JCD_API_KEY_PARAM_NAME andValue:JCD_API_KEY_PARAM_VALUE];
    [_wsRequest handleResultWith:^(id json) {
        NSLog(@"jcd ws result");
        _jcdRequestAttemptsNumber = 0;
        _stations = (NSMutableArray *)[Station fromJSONArray:json];
        NSLog(@"stations count %i", _stations.count);
        if (_mapViewState == MAP_VIEW_DEFAULT_STATE) {
            [self determineSpanCoordinates];
            [self drawStationsAroundUserAndZoom];
        }
        [self startTimer];
    }];
    [_wsRequest handleExceptionWith:^(NSError *exception) {
        if (exception.code == JCD_TIMED_OUT_REQUEST_EXCEPTION_CODE) {
            NSLog(@"jcd ws exception : expired request");
            if (_jcdRequestAttemptsNumber < 2) {
                [_wsRequest call];
                _jcdRequestAttemptsNumber++;
            } else {
                [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"dialog_error_title", @"") message:NSLocalizedString(@"jcd_ws_get_data_error", @"") delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil] show];
            }
        }
    }];
    
    NSLog(@"call ws");
    [_wsRequest call];
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
    [mapPanel setRegion:viewRegion animated:YES];
    NSLog(@"centered on Toulouse (%f,%f)", tls.latitude, tls.longitude);
}

# pragma mark Delegate

- (void)mapView:(MKMapView *)aMapView didUpdateUserLocation:(MKUserLocation *)aUserLocation {
    if (startUserLocation == nil) {
        startUserLocation = aUserLocation;
        [self centerMapOnUserLocation];
    }
}

- (void)mapView:(MKMapView *)aMapView regionDidChangeAnimated:(BOOL)animated {
    if (_isMapLoaded && _mapViewState == MAP_VIEW_DEFAULT_STATE) {
        NSLog(@"region has changed");
        [self determineSpanCoordinates];
        [self drawStationsAroundUserAndZoom];
    }
}

- (void)mapViewDidFinishLoadingMap:(MKMapView *)aMapView {
    NSLog(@"map is loaded");
    _isMapLoaded = true;
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
    if (annotation != mapPanel.userLocation) {
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

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    if (textField == self.bikeField || textField == self.standField || textField == self.radiusField) {
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

# pragma mark Event(s)

-(void)timerFired:(NSTimer *)theTimer
{
    NSLog(@"timer fired %@", [theTimer fireDate]);
    NSLog(@"call ws");
    [_wsRequest call];
}

- (IBAction)searchBarButtonClicked:(id)sender {
    _isSearchViewVisible = true;
    [self refreshNavigationBarHasSearchView:_isSearchViewVisible hasRideView:_mapViewState == MAP_VIEW_SEARCH_STATE];
    [UIView animateWithDuration:0.3 animations:^{
        CGRect searchFrame = self.searchPanel.frame;
        CGRect mapFrame = self.mapPanel.frame;
        searchFrame.origin.y = 0;
        mapFrame.origin.y = searchFrame.size.height;
        self.searchPanel.frame = searchFrame;
        self.mapPanel.frame = mapFrame;
    }];
}

- (void)cancelBarButtonClicked:(id)sender {
    if (_isSearchViewVisible) {
        _isSearchViewVisible = false;
        [UIView animateWithDuration:0.3 animations:^{
            CGRect searchFrame = self.searchPanel.frame;
            CGRect mapFrame = self.mapPanel.frame;
            searchFrame.origin.y = -searchFrame.size.height;
            mapFrame.origin.y = 0;
            [self.view endEditing:YES];
            self.searchPanel.frame = searchFrame;
            self.mapPanel.frame = mapFrame;
        }];
    } else {
        _mapViewState = MAP_VIEW_DEFAULT_STATE;
        [self resetSearchViewFields];
        [self eraseRoute];
        [self centerMapOnUserLocation];
        [self drawStationsAroundUserAndZoom];
    }
    [self refreshNavigationBarHasSearchView:_isSearchViewVisible hasRideView:_mapViewState == MAP_VIEW_SEARCH_STATE];
}

- (IBAction)bikeStepperClicked:(UIStepper *)stepper {
    self.bikeField.text = [NSString stringWithFormat:@"%d", (int) stepper.value];
    self.standStepper.value = (int) stepper.value;
    self.standField.text = [NSString stringWithFormat:@"%d", (int) stepper.value];
}

- (IBAction)standStepperClicked:(UIStepper *)stepper {
    self.standField.text = [NSString stringWithFormat:@"%d", (int) stepper.value];
}

- (IBAction)radiusStepperClicked:(UIStepper *)stepper {
    self.radiusField.text = [NSString stringWithFormat:@"%d", (int) stepper.value];
}

- (IBAction)userLocationAsDepartureClicked:(id)sender {
    CLLocationCoordinate2D userLocation = self.mapPanel.userLocation.coordinate;
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

- (IBAction)userLocationAsArrivalClicked:(id)sender {
    CLLocationCoordinate2D userLocation = self.mapPanel.userLocation.coordinate;
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

- (IBAction)searchButtonClicked:(id)sender {
    [self.view endEditing:YES];
    if (self.departureField.text.length == 0) {
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"dialog_warning_title", @"") message:NSLocalizedString(@"missing_departure", @"") delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil] show];
    } else if (self.arrivalField.text.length == 0) {
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"dialog_warning_title", @"") message:NSLocalizedString(@"missing_arrival", @"") delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil] show];
    } else {
        [self.view endEditing:YES];
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
                    [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"dialog_error_title", @"") message:NSLocalizedString(@"departure_not_found", @"") delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil] show];
                } else {
                    _departureLocation = [[placemarks objectAtIndex:0] location];
                    if (_departureLocation != nil && _arrivalLocation != nil) {
                        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                        if (![self areEqualLocationsBetween:_departureLocation and:_arrivalLocation]) {
                            [self cancelBarButtonClicked:nil];
                            [self searchWithDeparture:_departureLocation andArrival:_arrivalLocation withBikes:[self.bikeField.text intValue] andAvailableStands:[self.standField.text intValue] inARadiusOf:[self.radiusField.text intValue]];
                        } else {
                            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"dialog_warning_title", @"")  message:NSLocalizedString(@"same_location", @"") delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
                        }
                    }
                }
            }
        }];
        [arrivalGeocoder geocodeAddressString:self.arrivalField.text inRegion:nil completionHandler:^(NSArray *placemarks, NSError *error) {
            if (_searching) {
                if (error != nil) {
                    _searching = NO;
                    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                    [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"dialog_error_title", @"") message:NSLocalizedString(@"arrival_not_found", @"") delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil] show];
                } else {
                    _arrivalLocation = [[placemarks objectAtIndex:0] location];
                    if (_departureLocation != nil && _arrivalLocation != nil) {
                        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                        if (![self areEqualLocationsBetween:_departureLocation and:_arrivalLocation]) {
                            [self cancelBarButtonClicked:nil];
                            [self searchWithDeparture:_departureLocation andArrival:_arrivalLocation withBikes:[self.bikeField.text intValue] andAvailableStands:[self.standField.text intValue] inARadiusOf:[self.radiusField.text intValue]];
                        } else {
                            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"dialog_warning_title", @"")  message:NSLocalizedString(@"same_location", @"") delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
                        }
                    }
                }
            }
        }];
    }
}

# pragma mark Notification(s)

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

# pragma mark -
# pragma mark Navigation Bar

- (void)refreshNavigationBarHasSearchView:(BOOL)hasSearchView hasRideView:(BOOL)hasRideView {
    
    if (hasSearchView == false) {
        if (hasRideView == false) {
            self.navigationItem.rightBarButtonItems = nil;
            self.navigationItem.rightBarButtonItem = self.searchBarButton;
        } else {
            self.navigationItem.rightBarButtonItem = nil;
            self.navigationItem.rightBarButtonItems = @[self.cancelBarButton,self.searchBarButton];
        }
    } else {
        self.navigationItem.rightBarButtonItems = nil;
        self.navigationItem.rightBarButtonItem = self.cancelBarButton;
    }
}

# pragma mark Map panel

- (void)centerMapOnUserLocation {
    MKCoordinateRegion currentRegion = MKCoordinateRegionMakeWithDistance(startUserLocation.coordinate, SPAN_SIDE_INIT_LENGTH_IN_METERS, SPAN_SIDE_INIT_LENGTH_IN_METERS);
    [mapPanel setRegion:currentRegion animated:YES];
    NSLog(@"centered on user location (%f,%f)", startUserLocation.coordinate.latitude, startUserLocation.coordinate.longitude);
}

- (void)drawStationsAroundUserAndZoom {
    if (_stations != nil) {
        NSLog(@"display stations");
        [mapPanel removeAnnotations:mapPanel.annotations];
        int invalidStations = 0;
        int displayedStations = 0;
        for (Station *station in _stations) {
            if (station.latitude != (id)[NSNull null] && station.longitude != (id)[NSNull null]) {
                if ([self isVisibleStation:station]) {
                    [mapPanel addAnnotation:[self createStationAnnotation:station]];
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
    
    CLLocationCoordinate2D userLocation = self.mapPanel.userLocation.coordinate;
    CLLocationCoordinate2D spanCenter = self.mapPanel.region.center;
    
    if (stationCoordinate.latitude >= _northWestSpanCorner.latitude && stationCoordinate.latitude <= _southEastSpanCorner.latitude
        && stationCoordinate.longitude >= _northWestSpanCorner.longitude && stationCoordinate.longitude <= _southEastSpanCorner.longitude
        && ([self unlessInMeters:SPAN_SIDE_MAX_LENGTH_IN_METERS from:userLocation for:stationCoordinate]
            || [self unlessInMeters:SPAN_SIDE_MAX_LENGTH_IN_METERS from:spanCenter for:stationCoordinate])) {
            visible = true;
        }
    
    return visible;
}

- (void)determineSpanCoordinates {
    MKCoordinateRegion region = self.mapPanel.region;
    CLLocationCoordinate2D center = region.center;
    NSLog(@"determine span coordinates");
    _northWestSpanCorner.latitude  = center.latitude  - (region.span.latitudeDelta  / 2.0);
    _northWestSpanCorner.longitude = center.longitude - (region.span.longitudeDelta / 2.0);
    _southEastSpanCorner.latitude  = center.latitude  + (region.span.latitudeDelta  / 2.0);
    _southEastSpanCorner.longitude = center.longitude + (region.span.longitudeDelta / 2.0);
}

- (void)drawRouteEndsCloseStations {
    if ([_routeCloseStations count] == 0 || _closeStationsAroundDepartureNumber == 0 || _closeStationsAroundArrivalNumber == 0) {
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"dialog_info_title", @"")  message:NSLocalizedString(@"incomplete_search_result", @"") delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil] show];
    }
    // departure annotation
    MKPointAnnotation *marker = [[MKPointAnnotation alloc] init];
    marker.coordinate = _departureLocation.coordinate;
    marker.title = @"departure";
    
    [mapPanel addAnnotation:marker];
    
    // arrival annotation
    marker = [[MKPointAnnotation alloc] init];
    marker.coordinate = _arrivalLocation.coordinate;
    marker.title = @"arrival";
    
    [mapPanel addAnnotation:marker];
    
    for (Station *station in _routeCloseStations) {
        [mapPanel addAnnotation:[self createStationAnnotation:station]];
    }
}

- (void)drawRouteFromStationDeparture:(Station *)departure toStationArrival:(Station *)arrival {
    
    NSLog(@"searching for a route");
    WSRequest *googleRequest = [[WSRequest alloc] initWithResource:GOOGLE_MAPS_WS_ENTRY_POINT_PARAM_VALUE inBackground:NO];
    [googleRequest appendParameterWithKey:GOOGLE_MAPS_API_ORIGIN_PARAM_NAME andValue:[NSString stringWithFormat:@"%@,%@", departure.latitude, departure.longitude]];
    [googleRequest appendParameterWithKey:GOOGLE_MAPS_API_DESTINATION_PARAM_NAME andValue:[NSString stringWithFormat:@"%@,%@", arrival.latitude, arrival.longitude]];
    [googleRequest appendParameterWithKey:GOOGLE_MAPS_API_LANGUAGE_PARAM_NAME andValue:[[NSLocale currentLocale] objectForKey:NSLocaleCountryCode]];
    [googleRequest appendParameterWithKey:GOOGLE_MAPS_API_MODE_PARAM_NAME andValue:@"walking"];
    [googleRequest appendParameterWithKey:GOOGLE_MAPS_API_SENSOR_PARAM_NAME andValue:@"true"];
    [googleRequest handleResultWith:^(id json) {
        NSString *status = [json valueForKey:@"status"];
        
        if ([status isEqualToString:@"OK"]) {
            NSLog(@"find a route");
            
            NSString *encodedPolyline = [[[[json objectForKey:@"routes"] firstObject] objectForKey:@"overview_polyline"] valueForKey:@"points"];
            _route = [RoutePolyline routePolylineFromPolyline:[GeoUtils polylineWithEncodedString:encodedPolyline]];
            [mapPanel addOverlay:_route];
            [mapPanel setVisibleMapRect:_route.boundingMapRect animated:YES];
            
        } else {
            NSLog(@"Google Maps API error %@", status);
            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"dialog_error_title", @"")  message:@"Google Maps API error" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
        }
    }];
    [googleRequest handleErrorWith:^(int errorCode) {
        NSLog(@"HTTP error %d", errorCode);
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"dialog_error_title", @"")  message:@"HTTP error" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
    }];
    [googleRequest handleExceptionWith:^(NSError *exception) {
        NSLog(@"Exception %@", exception.debugDescription);
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"dialog_error_title", @"")  message:@"Exception" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
    }];
    [googleRequest call];
}

- (void)eraseRoute {
    if (_route != nil) {
        [mapPanel removeOverlay:_route];
        _route = nil;
    }
}

# pragma mark Search panel

- (void)resetSearchViewFields {
    self.departureField.text = nil;
    self.arrivalField.text = nil;
    self.bikeField.text = @"1";
    self.standField.text = @"1";
    self.radiusField.text = @"1000";
    
    _departureLocation = nil;
    _departureStation = nil;
    _arrivalLocation = nil;
    _arrivalStation = nil;
}

- (void)searchWithDeparture:(CLLocation *)departure andArrival:(CLLocation *)arrival withBikes:(int)bikes andAvailableStands:(int)availableStands inARadiusOf:(int)radius {
    NSLog(@"%f,%f -> %f,%f (%d / %d)", departure.coordinate.latitude, departure.coordinate.longitude, arrival.coordinate.latitude, arrival.coordinate.longitude, bikes, availableStands);
    _mapViewState = MAP_VIEW_SEARCH_STATE;
    [self refreshNavigationBarHasSearchView:_isSearchViewVisible hasRideView:_mapViewState == MAP_VIEW_SEARCH_STATE];
    [_routeCloseStations removeAllObjects];
    [self eraseRoute];
    _departureStation = nil;
    _arrivalStation = nil;
    [mapPanel removeAnnotations:mapPanel.annotations];
    _closeStationsAroundDepartureNumber = [self searchCloseStationsAround:departure isArrival:false withElementNumber:bikes andMaxStationsNumber:SEARCH_RESULT_MAX_STATIONS_NUMBER inARadiusOf:radius];
    _closeStationsAroundArrivalNumber = [self searchCloseStationsAround:arrival isArrival:true withElementNumber:availableStands andMaxStationsNumber:SEARCH_RESULT_MAX_STATIONS_NUMBER inARadiusOf:radius];
    [self drawRouteEndsCloseStations];
    if (_departureStation != nil && _arrivalStation != nil) {
      [self drawRouteFromStationDeparture:_departureStation toStationArrival:_arrivalStation];
    }
}

- (int)searchCloseStationsAround:(CLLocation *)location isArrival:(BOOL)arrival withElementNumber:(int)elementsNumber andMaxStationsNumber:(int)maxStationsNumber inARadiusOf:(int)maxRadius {
    NSLog(@"searching close stations");
    int matchingStationNumber = 0;
    
    int radius = STATION_SEARCH_RADIUS_IN_METERS;
    while (matchingStationNumber < maxStationsNumber && radius <= maxRadius) {
        for (Station *station in _stations) {
            if (matchingStationNumber < maxStationsNumber) {
                if (station.latitude != (id)[NSNull null] && station.longitude != (id)[NSNull null]) {
                    
                    CLLocationCoordinate2D stationCoordinate;
                    stationCoordinate.latitude = [station.latitude doubleValue];
                    stationCoordinate.longitude = [station.longitude doubleValue];
                    
                    if (![_routeCloseStations containsObject:station] && [self unlessInMeters:radius from:location.coordinate for:stationCoordinate]) {
                        if (!arrival && [station.availableBikes integerValue] >= elementsNumber) {
                            NSLog(@"close station found at %d m : %@ - %@ vélos dispos", radius, station.name, station.availableBikes);
                            [_routeCloseStations addObject:station];
                            if (_departureStation == nil) {
                                _departureStation = station;
                            }
                            matchingStationNumber++;
                        } else if (arrival && [station.availableBikeStands integerValue] >= elementsNumber) {
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

# pragma mark -
# pragma mark Misc

- (BOOL)unlessInMeters:(double)radius from:(CLLocationCoordinate2D)origin for:(CLLocationCoordinate2D)location {
    double dist = [GeoUtils getDistanceFromLat:origin.latitude toLat:location.latitude fromLong:origin.longitude toLong:location.longitude];
    return dist <= radius;
}

- (BOOL)areEqualLocationsBetween:(CLLocation *)first and:(CLLocation *)second {
    return fabs(first.coordinate.latitude - second.coordinate.latitude) < 0.001 &&
    fabs(first.coordinate.longitude - second.coordinate.longitude) < 0.001;
}

@end
