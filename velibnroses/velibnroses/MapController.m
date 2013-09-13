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
#import "PlaceAnnotation.h"
#import "UIUtils.h"
#import "TRAutocompleteView.h"
#import "TRGoogleMapsAutocompleteItemsSource.h"
#import "TRTextFieldExtensions.h"
#import "TRGoogleMapsAutocompletionCellFactory.h"
#import "Keys.h"

@interface MapController ()
    
@end

@implementation MapController {
    CLLocationCoordinate2D startUserLocation;
    WSRequest *_wsRequest;
    NSMutableArray *_stations;
    NSMutableArray *_departureCloseStations;
    NSMutableArray *_arrivalCloseStations;
    NSMutableArray *_stationsAnnotations;
    NSMutableArray *_searchAnnotations;
    BOOL _isMapLoaded;
    BOOL _searching;
    CLLocation *_departureLocation;
    CLLocation *_arrivalLocation;
    NSTimer *_timer;
    RoutePolyline *_route;
    int _mapViewState;
    BOOL _isSearchViewVisible;
    Station *_departureStation;
    Station *_arrivalStation;
    int _jcdRequestAttemptsNumber;
    NSNumber *_isLocationServiceEnabled;
    
    TRAutocompleteView *_departureAutocompleteView;
    TRAutocompleteView *_arrivalAutocompleteView;
}

@synthesize mapPanel;
@synthesize searchPanel;
@synthesize departureField;
@synthesize arrivalField;
@synthesize bikeField;
@synthesize standField;
@synthesize closeSearchPanelButton;
@synthesize searchBarButton;
@synthesize infoBarButton;
@synthesize searchButton;
@synthesize departureLocation;
@synthesize departureSpinner;
@synthesize arrivalLocation;
@synthesize arrivalSpinner;
@synthesize searchSpinner;

# pragma mark -

- (void)registerOn
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEnterBackgroundNotificationReceived:) name:NOTIFICATION_DID_ENTER_BACKGROUND object:nil];
    NSLog(@"register on %@", NOTIFICATION_DID_ENTER_BACKGROUND);
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForegroundNotificationReceived:) name:NOTIFICATION_WILL_ENTER_FOREGROUND object:nil];
    NSLog(@"register on %@", NOTIFICATION_WILL_ENTER_FOREGROUND);
}

- (void)resetUserLocation
{
    startUserLocation.latitude = 0;
    startUserLocation.longitude = 0;
}

- (void)initView
{
    self.mapPanel.delegate = self;
    self.mapPanel.showsUserLocation = YES;
    [self.mapPanel addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapMap:)]];
    
    self.navigationItem.titleView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Images/NavigationBar/NBLogo"]];
    
    CGRect searchFrame = self.searchPanel.frame;
    searchFrame.origin.y = -searchFrame.size.height;
    self.searchPanel.frame = searchFrame;
    self.bikeField.text = @"1";
    self.standField.text = @"1";
    self.cancelBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"Images/NavigationBar/NBClose"] style:UIBarButtonItemStyleBordered target:self action:@selector(cancelBarButtonClicked:)];
    
    departureSpinner.hidesWhenStopped = YES;
    [departureSpinner setColor:[UIUtils colorWithHexaString:@"#b2ca04"]];
    arrivalSpinner.hidesWhenStopped = YES;
    [arrivalSpinner setColor:[UIUtils colorWithHexaString:@"#b2ca04"]];
    searchSpinner.hidesWhenStopped = YES;
    [searchSpinner setColor:[UIUtils colorWithHexaString:@"#ffffff"]];
    [searchSpinner setHidden:true];
    
    _isMapLoaded = false;
    [self resetUserLocation];
    _mapViewState = MAP_VIEW_DEFAULT_STATE;
    _isSearchViewVisible = false;
    
    [self.infoBarButton setBackgroundImage:[UIImage new] forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    [self.searchBarButton setBackgroundImage:[UIImage new] forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    [self.cancelBarButton setBackgroundImage:[UIImage new] forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    
    UIImage *buttonBg = [[UIImage imageNamed:@"Images/SearchPanel/SPButtonBg"]
                         resizableImageWithCapInsets:UIEdgeInsetsMake(16, 16, 16, 16)];
    [self.searchButton setBackgroundImage:buttonBg forState:UIControlStateNormal];
    
    _departureCloseStations = [[NSMutableArray alloc] init];
    _arrivalCloseStations = [[NSMutableArray alloc] init];
    _stationsAnnotations = [[NSMutableArray alloc] init];
    _searchAnnotations = [[NSMutableArray alloc] init];
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
    [_wsRequest appendParameterWithKey:JCD_API_KEY_PARAM_NAME andValue:KEY_JCD];
    [_wsRequest handleResultWith:^(id json) {
        NSLog(@"jcd ws result");
        _jcdRequestAttemptsNumber = 0;
        _stations = (NSMutableArray *)[Station fromJSONArray:json];
        NSLog(@"stations count %i", _stations.count);
        dispatch_queue_t parent = dispatch_get_main_queue();
        dispatch_queue_t child = dispatch_queue_create("com.onelightstudio.onebike", NULL);
        dispatch_async(child, ^(void) {
            [self createStationsAnnotations];
            if (_mapViewState == MAP_VIEW_DEFAULT_STATE) {
                dispatch_async(parent, ^(void) {
                    [self displayStationsAnnotations];
                });
            } else {
                dispatch_async(parent, ^(void) {
                    Station *selectedDeparture = _departureStation.copy;
                    Station *selectedArrival = _arrivalStation.copy;
                    
                    [self eraseSearchAnnotations];
                    [self eraseRoute];
                    [self searchCloseStationsAroundDeparture:_departureLocation withBikesNumber:[self.bikeField.text intValue] andMaxStationsNumber:SEARCH_RESULT_MAX_STATIONS_NUMBER inARadiusOf:STATION_SEARCH_MAX_RADIUS_IN_METERS];
                    [self searchCloseStationsAroundArrival:_arrivalLocation withAvailableStandsNumber:[self.standField.text intValue] andMaxStationsNumber:SEARCH_RESULT_MAX_STATIONS_NUMBER inARadiusOf:STATION_SEARCH_MAX_RADIUS_IN_METERS];
                    [self drawSearchAnnotations];
                    if (![self isTheSameStationBetween:selectedDeparture and:_departureStation]) {
                        // user has selected another station than new one defined
                        for (Station *temp in _departureCloseStations) {
                            if ([self isTheSameStationBetween:selectedDeparture and:temp]) {
                                NSLog(@"set departure station to user initial choice");
                                _departureStation = temp;
                                break;
                            }
                        }
                    }
                    if (![self isTheSameStationBetween:selectedArrival and:_arrivalStation]) {
                        // user has selected another station than new one defined
                        for (Station *temp in _arrivalCloseStations) {
                            if ([self isTheSameStationBetween:selectedArrival and:temp]) {
                                NSLog(@"set arrival station to user initial choice");
                                _arrivalStation = temp;
                                break;
                            }
                        }
                    }
                    [self drawRouteFromStationDeparture:_departureStation toStationArrival:_arrivalStation];
                });
            }
        });
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
    if (!_isMapLoaded) {
        // centered by default on Toulouse
        CLLocationCoordinate2D tls;
        tls.latitude = TLS_LAT;
        tls.longitude = TLS_LONG;
        
        MKCoordinateRegion viewRegion = MKCoordinateRegionMakeWithDistance(tls, SPAN_SIDE_INIT_LENGTH_IN_METERS, SPAN_SIDE_INIT_LENGTH_IN_METERS);
        [mapPanel setRegion:viewRegion animated:YES];
        NSLog(@"centered on Toulouse (%f,%f)", tls.latitude, tls.longitude);
        
        _isLocationServiceEnabled = nil;
        if (![CLLocationManager locationServicesEnabled]) {
            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"dialog_warning_title", @"") message:NSLocalizedString(@"no_location_activated", @"") delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil] show];
            _isLocationServiceEnabled = [NSNumber numberWithBool:NO];
        } else if ([CLLocationManager authorizationStatus] != kCLAuthorizationStatusNotDetermined && [CLLocationManager authorizationStatus] != kCLAuthorizationStatusAuthorized) {
            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"dialog_warning_title", @"") message:NSLocalizedString(@"no_location_allowed", @"") delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil] show];
            _isLocationServiceEnabled = [NSNumber numberWithBool:NO];
        } else if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorized) {
            _isLocationServiceEnabled = [NSNumber numberWithBool:YES];
        }
    }
}

# pragma mark Delegate

- (void)mapView:(MKMapView *)aMapView didUpdateUserLocation:(MKUserLocation *)aUserLocation {
    if ([self isEqualToLocationZero:startUserLocation]) {
        NSLog(@"receive user location update (%f,%f)", aUserLocation.location.coordinate.latitude, aUserLocation.location.coordinate.longitude);
        if (![self isEqualToLocationZero:aUserLocation.location.coordinate]) {
            startUserLocation = aUserLocation.location.coordinate;
            [self centerMapOnUserLocation];
            
            _departureAutocompleteView = [TRAutocompleteView autocompleteViewBindedTo:departureField usingSource:[[TRGoogleMapsAutocompleteItemsSource alloc] initWithMinimumCharactersToTrigger:3 withApiKey:KEY_GOOGLE_PLACES andUserLocation:startUserLocation]cellFactory:[[TRGoogleMapsAutocompletionCellFactory alloc] initWithCellForegroundColor:[UIColor lightGrayColor] fontSize:14] presentingIn:self];
            _departureAutocompleteView.topMargin = -65;
            _departureAutocompleteView.backgroundColor = [UIUtils colorWithHexaString:@"#FFFFFF"];
            _departureAutocompleteView.didAutocompleteWith = ^(id<TRSuggestionItem> item)
            {
                NSLog(@"Departure autocompleted with: %@", item.completionText);
            };
            
            _arrivalAutocompleteView = [TRAutocompleteView autocompleteViewBindedTo:arrivalField usingSource:[[TRGoogleMapsAutocompleteItemsSource alloc] initWithMinimumCharactersToTrigger:3 withApiKey:KEY_GOOGLE_PLACES andUserLocation:startUserLocation]cellFactory:[[TRGoogleMapsAutocompletionCellFactory alloc] initWithCellForegroundColor:[UIColor lightGrayColor] fontSize:14] presentingIn:self];
            _arrivalAutocompleteView.topMargin = -65;
            _arrivalAutocompleteView.backgroundColor = [UIUtils colorWithHexaString:@"#FFFFFF"];
            _arrivalAutocompleteView.didAutocompleteWith = ^(id<TRSuggestionItem> item)
            {
                NSLog(@"Arrival autocompleted with: %@", item.completionText);
            };
        }
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
    if ([UIScreen instancesRespondToSelector:@selector(scale)] && [[UIScreen mainScreen] scale] == 2.0f) {
        polylineView.lineWidth = 10;
    } else {
        polylineView.lineWidth = 5;
    }
    polylineView.strokeColor = [UIUtils colorWithHexaString:@"#b2ca04"];
    return polylineView;
}

- (MKAnnotationView *)mapView:(MKMapView *)aMapView viewForAnnotation:(id <MKAnnotation>)anAnnotation
{
    MKPinAnnotationView *annotationView;
    static NSString *annotationID;
    
    if (anAnnotation != mapPanel.userLocation) {
        if ([anAnnotation isKindOfClass:[PlaceAnnotation class]]) {
            PlaceAnnotation *annotation = anAnnotation;

            if (annotation.placeType == kDeparture) {
                annotationID = @"Departure";
                //NSLog(@"process %@", annotationID);
                annotationView = (MKPinAnnotationView *)[aMapView dequeueReusableAnnotationViewWithIdentifier:annotationID];
                if (annotationView == nil) {
                    annotationView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:annotationID];
                    annotationView.image =  [UIImage imageNamed:@"Images/MapPanel/MPDeparture"];
                    //NSLog(@"create");
                } else {
                    //NSLog(@"reuse");
                }
            } else if (annotation.placeType == kArrival) {
                annotationID = @"Arrival";
                //NSLog(@"process %@", annotationID);
                annotationView = (MKPinAnnotationView *)[aMapView dequeueReusableAnnotationViewWithIdentifier:annotationID];
                if (annotationView == nil) {
                    annotationView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:annotationID];
                    annotationView.image =  [UIImage imageNamed:@"Images/MapPanel/MPArrival"];
                    //NSLog(@"create");
                } else {
                    //NSLog(@"reuse");
                }
            } else {
                NSMutableString *loc = [[NSMutableString alloc] initWithString:[annotation.placeStation.latitude stringValue]];
                [loc appendString:@","];
                [loc appendString:[annotation.placeStation.longitude stringValue]];
                annotationID = [NSString stringWithString:loc];
                //NSLog(@"process %@", annotationID);
                annotationView = (MKPinAnnotationView *)[aMapView dequeueReusableAnnotationViewWithIdentifier:annotationID];
                if (annotationView == nil) {
                    annotationView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:annotationID];
                    //NSLog(@"create : %@/%@", annotation.placeStation.availableBikes, annotation.placeStation.availableBikeStands);
                } else {
                    //NSLog(@"reuse (%@)", annotationView.reuseIdentifier);
                }
                UIImage *background = [UIImage imageNamed:@"Images/MapPanel/MPStation"];
                UIImage *bikes = [UIUtils drawBikesText:[annotation.placeStation.availableBikes stringValue]];
                UIImage *tmp = [UIUtils placeBikes:bikes onImage:background];
                UIImage *stands = [UIUtils drawStandsText:[annotation.placeStation.availableBikeStands stringValue]];
                UIImage *image = [UIUtils placeStands:stands onImage:tmp];
                annotationView.image = image;
            }
        }
        annotationView.canShowCallout = YES;
    }
    return annotationView;
}

- (void)mapView:(MKMapView *)aMapView didSelectAnnotationView:(MKAnnotationView *)aView {
    if (!_isSearchViewVisible && _mapViewState == MAP_VIEW_SEARCH_STATE) {
        if ([aView.annotation isKindOfClass:[PlaceAnnotation class]]) {
            PlaceAnnotation *annotation = aView.annotation;
            if (annotation.placeType != kDeparture && annotation.placeType != kArrival && annotation.placeLocation != kUndefined) {
                BOOL redraw = false;
                if (annotation.placeLocation == kNearDeparture && _departureStation != annotation.placeStation) {
                    NSLog(@"change departure");
                    _departureStation = annotation.placeStation;
                    redraw = true;
                } else if (annotation.placeLocation == kNearArrival && _arrivalStation != annotation.placeStation) {
                    NSLog(@"change arrival");
                    _arrivalStation = annotation.placeStation;
                    redraw = true;
                }
                if (redraw) {
                    [self eraseRoute];
                    [self drawRouteFromStationDeparture:_departureStation toStationArrival:_arrivalStation];
                }
            }
        }
    }
    
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField {
    if (textField == self.departureField) {
        [_departureAutocompleteView hide];
    } else if (textField == self.arrivalField) {
        [_arrivalAutocompleteView hide];
    } else if (textField == self.bikeField) {
        if ([textField.text isEqualToString:@""] || [textField.text integerValue] == 0) {
            self.bikeField.text = @"1";
        } else if (textField.text.length > 2) {
            self.bikeField.text = @"99";
        }
        self.standField.text = self.bikeField.text;
    } else if (textField == self.standField) {
        if ([textField.text isEqualToString:@""] || [textField.text integerValue] == 0) {
            self.standField.text = @"1";
        } else if (textField.text.length > 2) {
            self.standField.text = @"99";
        }
    }
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.departureField) {
        [self.arrivalField becomeFirstResponder];
    } else {
        [self.view endEditing:YES];
    }
    return YES;
}

# pragma mark Event(s)

-(void)timerFired:(NSTimer *)theTimer
{
    NSLog(@"timer fired %@", [theTimer fireDate]);
    NSLog(@"call ws");
    [_wsRequest call];
}

- (void)didTapMap:(UITapGestureRecognizer *)sender
{
    NSLog(@"tap map fired");
    if (_isSearchViewVisible) {
        _isSearchViewVisible = false;
        [self closeSearchPanel];
    }
    [self refreshNavigationBarHasSearchView:_isSearchViewVisible hasRideView:_mapViewState == MAP_VIEW_SEARCH_STATE];
}

- (IBAction)searchBarButtonClicked:(id)sender {
    _isSearchViewVisible = true;
    [self openSearchPanel];
    [self refreshNavigationBarHasSearchView:_isSearchViewVisible hasRideView:_mapViewState == MAP_VIEW_SEARCH_STATE];
}

- (IBAction)cancelBarButtonClicked:(id)sender {
    if (_isSearchViewVisible) {
        _isSearchViewVisible = false;
        [self closeSearchPanel];
    } else {
        _mapViewState = MAP_VIEW_DEFAULT_STATE;
        [self resetSearchViewFields];
        [self eraseRoute];
        [self centerMapOnUserLocation];
        [self eraseSearchAnnotations];
        dispatch_queue_t parent = dispatch_get_main_queue();
        dispatch_queue_t child = dispatch_queue_create("com.onelightstudio.onebike", NULL);
        dispatch_async(child, ^(void) {
            // necessary time to trigger effective zoom
            [NSThread sleepForTimeInterval:1.0f];
            dispatch_async(parent, ^(void) {
                [self displayStationsAnnotations];
            });
        });
    }
    [self refreshNavigationBarHasSearchView:_isSearchViewVisible hasRideView:_mapViewState == MAP_VIEW_SEARCH_STATE];
}

- (IBAction)backBarButtonClicked:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)bikeIconClicked:(id)sender {
    [self.bikeField becomeFirstResponder];
}

- (IBAction)standIconClicked:(id)sender {
    [self.standField becomeFirstResponder];
}

- (IBAction)userLocationAsDepartureClicked:(id)sender {
    [self.departureLocation setHidden:true];
    [self.departureSpinner startAnimating];
    
    CLLocationCoordinate2D userLocation = self.mapPanel.userLocation.coordinate;
    CLLocation *location = [[CLLocation alloc] initWithLatitude:userLocation.latitude longitude:userLocation.longitude];
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    [geocoder reverseGeocodeLocation:location completionHandler:^(NSArray *placemarks, NSError *error) {
        if (error != nil) {
            self.departureField.text = [NSString stringWithFormat:@"%f,%f", userLocation.latitude, userLocation.longitude];
        } else {
            self.departureField.text = [[[(CLPlacemark *)[placemarks objectAtIndex:0] addressDictionary] valueForKey:@"FormattedAddressLines"] componentsJoinedByString:@", "];
        }
        [self.departureSpinner stopAnimating];
        [self.departureLocation setHidden:false];
    }];
}

- (IBAction)userLocationAsArrivalClicked:(id)sender {
    [self.arrivalLocation setHidden:true];
    [self.arrivalSpinner startAnimating];
    
    CLLocationCoordinate2D userLocation = self.mapPanel.userLocation.coordinate;
    CLLocation *location = [[CLLocation alloc] initWithLatitude:userLocation.latitude longitude:userLocation.longitude];
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    [geocoder reverseGeocodeLocation:location completionHandler:^(NSArray *placemarks, NSError *error) {
        if (error != nil) {
            self.arrivalField.text = [NSString stringWithFormat:@"%f,%f", userLocation.latitude, userLocation.longitude];
        } else {
            self.arrivalField.text = [[[(CLPlacemark *)[placemarks objectAtIndex:0] addressDictionary] valueForKey:@"FormattedAddressLines"] componentsJoinedByString:@", "];
        }
        [self.arrivalSpinner stopAnimating];
        [self.arrivalLocation setHidden:false];
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
        [self disableSearchButton];
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
                   [self enableSearchButton];
                } else {
                    _departureLocation = [[placemarks objectAtIndex:0] location];
                    if (_departureLocation != nil && _arrivalLocation != nil) {
                        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                        if (![self areEqualLocationsBetween:_departureLocation and:_arrivalLocation]) {
                            [self cancelBarButtonClicked:nil];
                            [self searchWithDeparture:_departureLocation andArrival:_arrivalLocation withBikes:[self.bikeField.text intValue] andAvailableStands:[self.standField.text intValue] inARadiusOf:STATION_SEARCH_MAX_RADIUS_IN_METERS];
                        } else {
                            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"dialog_warning_title", @"")  message:NSLocalizedString(@"same_location", @"") delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
                            [self enableSearchButton];
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
                    [self enableSearchButton];
                } else {
                    _arrivalLocation = [[placemarks objectAtIndex:0] location];
                    if (_departureLocation != nil && _arrivalLocation != nil) {
                        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                        if (![self areEqualLocationsBetween:_departureLocation and:_arrivalLocation]) {
                            [self cancelBarButtonClicked:nil];
                            [self searchWithDeparture:_departureLocation andArrival:_arrivalLocation withBikes:[self.bikeField.text intValue] andAvailableStands:[self.standField.text intValue] inARadiusOf:STATION_SEARCH_MAX_RADIUS_IN_METERS];
                        } else {
                            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"dialog_warning_title", @"")  message:NSLocalizedString(@"same_location", @"") delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
                            [self enableSearchButton];
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
        [self resetUserLocation];
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
        self.navigationItem.rightBarButtonItem = nil;
    }
}

# pragma mark Map panel

- (void)centerMapOnUserLocation {
    MKCoordinateRegion currentRegion = MKCoordinateRegionMakeWithDistance(startUserLocation, SPAN_SIDE_INIT_LENGTH_IN_METERS, SPAN_SIDE_INIT_LENGTH_IN_METERS);
    [mapPanel setRegion:currentRegion animated:YES];
    NSLog(@"centered on user location (%f,%f)", startUserLocation.latitude, startUserLocation.longitude);
}

- (void)createStationsAnnotations {
    NSLog(@"create stations annotations");
    [self eraseAnnotations];
    [_stationsAnnotations removeAllObjects];
    int invalidStations = 0;
    int displayedStations = 0;
    for (Station *station in _stations) {
        if (station.latitude != (id)[NSNull null] && station.longitude != (id)[NSNull null]) {
            [_stationsAnnotations addObject:[self createStationAnnotation:station withLocation:kUndefined]];
            displayedStations++;
        } else {
            NSLog(@"%@ : %@", station.name, station.contract);
            invalidStations++;
        }
    }
    NSLog(@"localized stations count : %i", displayedStations);
    if (invalidStations > 0) {
        NSLog(@"invalid stations count : %i", invalidStations);
    }
}

- (void)displayStationsAnnotations {
    NSLog(@"display stations");
    [mapPanel addAnnotations:_stationsAnnotations];
}

- (void)createStationsAnnotationsAroundDeparture {
    for (Station *station in _departureCloseStations) {
        [_searchAnnotations addObject:[self createStationAnnotation:station withLocation:kNearDeparture]];
    }
}

- (void)createStationsAnnotationsAroundArrival {
    for (Station *station in _arrivalCloseStations) {
        [_searchAnnotations addObject:[self createStationAnnotation:station withLocation:kNearArrival]];
    }
}

- (void)drawRouteEndsClosedStations {
    [self createStationsAnnotationsAroundDeparture];
    [self createStationsAnnotationsAroundArrival];
    [mapPanel addAnnotations:_searchAnnotations];
}

- (PlaceAnnotation *)createStationAnnotation:(Station *)aStation withLocation:(PlaceAnnotationLocation) aLocation {
    
    CLLocationCoordinate2D stationCoordinate;
    stationCoordinate.latitude = [aStation.latitude doubleValue];
    stationCoordinate.longitude = [aStation.longitude doubleValue];
    
    PlaceAnnotation *marker = [[PlaceAnnotation alloc] init];
    marker.placeLocation = aLocation;
    marker.coordinate = stationCoordinate;
    marker.title = [self cleanStationName:aStation];
    marker.placeStation = aStation;
    return marker;
}

- (void)drawSearchAnnotations {
    
    NSLog(@"draw search annotations");
    // departure annotation
    PlaceAnnotation *marker = [[PlaceAnnotation alloc] init];
    marker.placeType = kDeparture;
    marker.coordinate = _departureLocation.coordinate;
    marker.title = self.departureField.text;
    
    [_searchAnnotations addObject:marker];
    
    // arrival annotation
    marker = [[PlaceAnnotation alloc] init];
    marker.placeType = kArrival;
    marker.coordinate = _arrivalLocation.coordinate;
    marker.title = self.arrivalField.text;
    
    [_searchAnnotations addObject:marker];
    
    [self drawRouteEndsClosedStations];
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
            [mapPanel setVisibleMapRect:[self mapRectWithAllAnnotations] animated:YES];
            
        } else {
            NSLog(@"Google Maps API error %@", status);
            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"dialog_error_title", @"")  message:@"Google Maps API error" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
        }
        [self enableSearchButton];
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
        NSLog(@"erase route");
        [mapPanel removeOverlay:_route];
        _route = nil;
    }
}

- (void)eraseAnnotations {
    if (_stationsAnnotations != nil) {
        NSLog(@"erase stations annotations");
        [mapPanel removeAnnotations:_stationsAnnotations];
    }
}

- (void)eraseSearchAnnotations {
    if (_searchAnnotations != nil) {
        NSLog(@"erase search annotations");
        [mapPanel removeAnnotations:_searchAnnotations];
        [_searchAnnotations removeAllObjects];
        [_departureCloseStations removeAllObjects];
        [_arrivalCloseStations removeAllObjects];
        _departureStation = nil;
        _arrivalStation = nil;
    }
}

- (MKMapRect)mapRectWithAllAnnotations {
    
    MKMapRect mapRect = MKMapRectNull;
    for (id<MKAnnotation> annotation in _searchAnnotations) {
        
        MKMapPoint annotationPoint = MKMapPointForCoordinate(annotation.coordinate);
        MKMapRect pointRect = MKMapRectMake(annotationPoint.x, annotationPoint.y, 0, 0);
        
        if (MKMapRectIsNull(mapRect)) {
            mapRect = pointRect;
        } else {
            mapRect = MKMapRectUnion(mapRect, pointRect);
        }
    }
    return mapRect;
}

# pragma mark Search panel

- (void)enableSearchButton {
    searchButton.enabled = true;
    [searchButton setTitle:NSLocalizedString(@"7ZO-mt-kun.normalTitle", @"") forState:UIControlStateApplication];
    [searchSpinner setHidden:true];
}

- (void)disableSearchButton {
    searchButton.enabled = false;
    [searchButton setTitle:@"" forState:UIControlStateDisabled];
    [searchSpinner setHidden:false];
    [self.searchSpinner startAnimating];
}

- (void)resetSearchViewFields {
    self.departureField.text = nil;
    self.arrivalField.text = nil;
    self.bikeField.text = @"1";
    self.standField.text = @"1";
    
    _departureLocation = nil;
    _departureStation = nil;
    _arrivalLocation = nil;
    _arrivalStation = nil;
}

- (void)openSearchPanel {
    [UIView animateWithDuration:0.5 animations:^{
        CGRect searchFrame = self.searchPanel.frame;
        searchFrame.origin.y = 0;
        self.searchPanel.frame = searchFrame;
    }];
    if (_isLocationServiceEnabled != nil) {
        self.departureLocation.enabled = [_isLocationServiceEnabled boolValue];
        self.arrivalLocation.enabled = [_isLocationServiceEnabled boolValue];
    } else {
        BOOL allowed = [CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorized;
        self.departureLocation.enabled = allowed;
        self.arrivalLocation.enabled = allowed;
    }
    [self enableSearchButton];
}

- (void)closeSearchPanel {
    [UIView animateWithDuration:0.5 animations:^{
        CGRect searchFrame = self.searchPanel.frame;
        searchFrame.origin.y = -searchFrame.size.height;
        self.searchPanel.frame = searchFrame;
    }];
}

- (void)searchWithDeparture:(CLLocation *)departure andArrival:(CLLocation *)arrival withBikes:(int)bikes andAvailableStands:(int)availableStands inARadiusOf:(int)radius {
    NSLog(@"%f,%f -> %f,%f (%d / %d)", departure.coordinate.latitude, departure.coordinate.longitude, arrival.coordinate.latitude, arrival.coordinate.longitude, bikes, availableStands);
    _mapViewState = MAP_VIEW_SEARCH_STATE;
    [self refreshNavigationBarHasSearchView:_isSearchViewVisible hasRideView:_mapViewState == MAP_VIEW_SEARCH_STATE];
    [self eraseRoute];
    [self eraseSearchAnnotations];
    [self eraseAnnotations];
    [self searchCloseStationsAroundDeparture:departure withBikesNumber:bikes andMaxStationsNumber:SEARCH_RESULT_MAX_STATIONS_NUMBER inARadiusOf:radius];
    [self searchCloseStationsAroundArrival:arrival withAvailableStandsNumber:availableStands andMaxStationsNumber:SEARCH_RESULT_MAX_STATIONS_NUMBER inARadiusOf:radius];
    if ([_departureCloseStations count] > 0 && [_arrivalCloseStations count] > 0 && _departureStation != nil && _arrivalStation != nil) {
        [self drawSearchAnnotations];
        [self drawRouteFromStationDeparture:_departureStation toStationArrival:_arrivalStation];
    } else {
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"dialog_info_title", @"")  message:NSLocalizedString(@"incomplete_search_result", @"") delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil] show];
        [self centerMapOnUserLocation];
    }
}

- (void)searchCloseStationsAroundDeparture:(CLLocation *)location withBikesNumber:(int)bikesNumber andMaxStationsNumber:(int)maxStationsNumber inARadiusOf:(int)maxRadius {
    NSLog(@"searching %d close stations around departure", maxStationsNumber);
    int matchingStationNumber = 0;
    
    int radius = STATION_SEARCH_RADIUS_IN_METERS;
    while (matchingStationNumber < maxStationsNumber && radius <= maxRadius) {
        for (Station *station in _stations) {
            if (matchingStationNumber < maxStationsNumber) {
                if (station.latitude != (id)[NSNull null] && station.longitude != (id)[NSNull null]) {
                    
                    CLLocationCoordinate2D stationCoordinate;
                    stationCoordinate.latitude = [station.latitude doubleValue];
                    stationCoordinate.longitude = [station.longitude doubleValue];
                    
                    if (![_departureCloseStations containsObject:station] && [self unlessInMeters:radius from:location.coordinate for:stationCoordinate]) {
                        if ([station.availableBikes integerValue] >= bikesNumber) {
                            NSLog(@"close station found at %d m : %@ - %@ available bikes", radius, station.name, station.availableBikes);
                            [_departureCloseStations addObject:station];
                            if (_departureStation == nil) {
                                _departureStation = station;
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
}

- (void)searchCloseStationsAroundArrival:(CLLocation *)location withAvailableStandsNumber:(int)availableStandsNumber andMaxStationsNumber:(int)maxStationsNumber inARadiusOf:(int)maxRadius {
    NSLog(@"searching %d close stations around arrival", maxStationsNumber);
    int matchingStationNumber = 0;
    
    int radius = STATION_SEARCH_RADIUS_IN_METERS;
    while (matchingStationNumber < maxStationsNumber && radius <= maxRadius) {
        for (Station *station in _stations) {
            if (matchingStationNumber < maxStationsNumber) {
                if (station.latitude != (id)[NSNull null] && station.longitude != (id)[NSNull null]) {
                    
                    CLLocationCoordinate2D stationCoordinate;
                    stationCoordinate.latitude = [station.latitude doubleValue];
                    stationCoordinate.longitude = [station.longitude doubleValue];
                    
                    if (![_arrivalCloseStations containsObject:station] && [self unlessInMeters:radius from:location.coordinate for:stationCoordinate]) {
                        if ([station.availableBikeStands integerValue] >= availableStandsNumber) {
                            NSLog(@"close station found at %d m : %@ - %@ available stands", radius, station.name, station.availableBikeStands);
                            [_arrivalCloseStations addObject:station];
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
}

# pragma mark -
# pragma mark Misc

- (BOOL)unlessInMeters:(double)radius from:(CLLocationCoordinate2D)origin for:(CLLocationCoordinate2D)location {
    double dist = [GeoUtils getDistanceFromLat:origin.latitude toLat:location.latitude fromLong:origin.longitude toLong:location.longitude];
    return dist <= radius;
}

- (BOOL)isEqualToLocationZero:(CLLocationCoordinate2D)newLocation {
    BOOL isLocationZero = fabs(newLocation.latitude - 0.00000) < 0.00001 && fabs(newLocation.longitude -  - 0.00000) < 0.00001;
    if (isLocationZero) {
        NSLog(@"location zero");
    }
    return isLocationZero;
}

- (BOOL)areEqualLocationsBetween:(CLLocation *)first and:(CLLocation *)second {
    return fabs(first.coordinate.latitude - second.coordinate.latitude) < 0.001 && fabs(first.coordinate.longitude - second.coordinate.longitude) < 0.001;
}

- (BOOL)isTheSameStationBetween:(Station *)first and:(Station *)second {
    return fabs(first.latitude.doubleValue - second.latitude.doubleValue) < 0.001 && fabs(first.longitude.doubleValue - second.longitude.doubleValue) < 0.001;
}

- (NSString *)cleanStationName:(Station *)aStation {
    NSString *regexp = @"^[a-zA-Z](.*)$";
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@",regexp];
    NSMutableString *tmp = [aStation.name mutableCopy];
    while (![predicate evaluateWithObject: tmp] || tmp.length == 0) {
        // remove first character while is not a letter
        tmp = (NSMutableString *)[tmp substringFromIndex:1];
    }
    
    NSString *result;
    if (tmp.length > 0) {
        result = [NSString stringWithString:tmp];
    } else {
        result = @"###";
    }
    return result;
}

@end
