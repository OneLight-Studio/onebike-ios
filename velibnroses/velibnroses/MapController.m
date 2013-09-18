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
#import "ClusterAnnotation.h"

@interface MapController ()
    
@end

@implementation MapController {
    CLLocationCoordinate2D _startUserLocation;
    WSRequest *_jcdRequest;
    NSMutableArray *_allStations;
    NSMutableArray *_noClusterizedStations;
    
    NSMutableArray *_clustersAnnotationsToAdd;
    NSMutableArray *_clustersAnnotationsToRetain;
    NSMutableArray *_clustersAnnotationsToRemove;
    NSMutableArray *_stationsAnnotationsToAdd;
    NSMutableArray *_stationsAnnotationsToRetain;
    NSMutableArray *_stationsAnnotationsToRemove;
    
    NSMutableArray *_departureCloseStations;
    NSMutableArray *_arrivalCloseStations;
    NSMutableArray *_searchAnnotations;
    BOOL _isMapLoaded;
    BOOL _isStationsDisplayedAtLeastOnce;
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
    UIAlertView *_rideUIAlert;
    TRAutocompleteView *_departureAutocompleteView;
    TRAutocompleteView *_arrivalAutocompleteView;
    int _currentZoomLevel;
    BOOL _isZoomIn;
    BOOL _isZoomOut;
    
    dispatch_queue_t uiQueue;
    dispatch_queue_t oneBikeQueue;
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
    _startUserLocation.latitude = 0;
    _startUserLocation.longitude = 0;
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
    _isStationsDisplayedAtLeastOnce = false;
    [self resetUserLocation];
    _mapViewState = MAP_VIEW_DEFAULT_STATE;
    _isSearchViewVisible = false;
    
    [self.infoBarButton setBackgroundImage:[UIImage new] forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    [self.searchBarButton setBackgroundImage:[UIImage new] forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    [self.cancelBarButton setBackgroundImage:[UIImage new] forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    
    UIImage *buttonBg = [[UIImage imageNamed:@"Images/SearchPanel/SPButtonBg"]
                         resizableImageWithCapInsets:UIEdgeInsetsMake(16, 16, 16, 16)];
    [self.searchButton setBackgroundImage:buttonBg forState:UIControlStateNormal];
    
    //_allStationsAnnotations = [[NSMutableArray alloc] init];
    
    _clustersAnnotationsToAdd = [[NSMutableArray alloc] init];
    _clustersAnnotationsToRetain = [[NSMutableArray alloc] init];
    _clustersAnnotationsToRemove = [[NSMutableArray alloc] init];
    _stationsAnnotationsToAdd = [[NSMutableArray alloc] init];
    _stationsAnnotationsToRetain = [[NSMutableArray alloc] init];
    _stationsAnnotationsToRemove = [[NSMutableArray alloc] init];
    
    _departureCloseStations = [[NSMutableArray alloc] init];
    _arrivalCloseStations = [[NSMutableArray alloc] init];
    _searchAnnotations = [[NSMutableArray alloc] init];
    
    _rideUIAlert = nil;
    _isZoomIn = false;
    _isZoomOut = false;
    
    uiQueue = dispatch_get_main_queue();
    oneBikeQueue = dispatch_queue_create("com.onelightstudio.onebike", NULL);
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
    _jcdRequest = [[WSRequest alloc] initWithResource:JCD_WS_ENTRY_POINT_PARAM_VALUE inBackground:TRUE];
    [_jcdRequest appendParameterWithKey:JCD_API_KEY_PARAM_NAME andValue:KEY_JCD];
    [_jcdRequest handleResultWith:^(id json) {
        NSLog(@"jcd ws result");
        _jcdRequestAttemptsNumber = 0;
        _allStations = (NSMutableArray *)[Station fromJSONArray:json];
        NSLog(@"stations count %i", _allStations.count);
        //[self drawStationsAnnotationsWithReset:true];
        
        NSLog(@"draw stations");
        //dispatch_queue_t parent = dispatch_get_main_queue();
        //dispatch_queue_t child = dispatch_queue_create("com.onelightstudio.onebike", NULL);
        if (_mapViewState == MAP_VIEW_DEFAULT_STATE) {
            dispatch_async(oneBikeQueue, ^(void) {
                [self filterStationsAnnotationsWithReset:true];
                dispatch_async(uiQueue, ^(void) {
                    [mapPanel removeAnnotations:_clustersAnnotationsToRemove];
                    [mapPanel removeAnnotations:_stationsAnnotationsToRemove];
                    [mapPanel addAnnotations:_clustersAnnotationsToAdd];
                    [mapPanel addAnnotations:_stationsAnnotationsToAdd];
                    [_stationsAnnotationsToRemove addObjectsFromArray:_stationsAnnotationsToAdd];
                    [_stationsAnnotationsToAdd removeAllObjects];
                    [_clustersAnnotationsToRemove removeAllObjects];
                    [_clustersAnnotationsToRemove addObjectsFromArray:_clustersAnnotationsToAdd];
                    [_clustersAnnotationsToAdd removeAllObjects];
                    if (!_isStationsDisplayedAtLeastOnce) {
                        _isStationsDisplayedAtLeastOnce = true;
                    }
                });
            });
        } else {
            dispatch_async(uiQueue, ^(void) {
                [self eraseSearchAnnotations];
                [self eraseRoute];
            });
            dispatch_async(oneBikeQueue, ^(void) {
                Station *selectedDeparture = _departureStation.copy;
                Station *selectedArrival = _arrivalStation.copy;
                BOOL isSameDeparture = true;
                BOOL isSameArrival = true;
                double radius = [self getDistanceBetweenDeparture:_departureLocation andArrival:_arrivalLocation withMin:STATION_SEARCH_MIN_RADIUS_IN_METERS withMax:STATION_SEARCH_MAX_RADIUS_IN_METERS];
                [self searchCloseStationsAroundDeparture:_departureLocation withBikesNumber:[self.bikeField.text intValue] andMaxStationsNumber:SEARCH_RESULT_MAX_STATIONS_NUMBER inARadiusOf:radius];
                [self searchCloseStationsAroundArrival:_arrivalLocation withAvailableStandsNumber:[self.standField.text intValue] andMaxStationsNumber:SEARCH_RESULT_MAX_STATIONS_NUMBER inARadiusOf:radius];
                if (![self isTheSameStationBetween:selectedDeparture and:_departureStation]) {
                    isSameDeparture = false;
                    // user has selected another station than new one defined
                    for (Station *temp in _departureCloseStations) {
                        if ([self isTheSameStationBetween:selectedDeparture and:temp]) {
                            NSLog(@"set departure station to user initial choice");
                            _departureStation = temp;
                            isSameDeparture = true;
                            break;
                        }
                    }
                }
                if (![self isTheSameStationBetween:selectedArrival and:_arrivalStation]) {
                    isSameArrival = false;
                    // user has selected another station than new one defined
                    for (Station *temp in _arrivalCloseStations) {
                        if ([self isTheSameStationBetween:selectedArrival and:temp]) {
                            NSLog(@"set arrival station to user initial choice");
                            _arrivalStation = temp;
                            isSameArrival = true;
                            break;
                        }
                    }
                }
                dispatch_async(uiQueue, ^(void) {
                    if (_rideUIAlert != nil) {
                        [_rideUIAlert dismissWithClickedButtonIndex:0 animated:YES];
                    }
                    if ([_departureCloseStations count] > 0 && [_arrivalCloseStations count] > 0 && _departureStation != nil && _arrivalStation != nil) {
                        [self drawSearchAnnotations];
                        [self drawRouteFromStationDeparture:_departureStation toStationArrival:_arrivalStation];
                        if (!isSameDeparture || !isSameArrival) {
                            _rideUIAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"dialog_info_title", @"") message:NSLocalizedString(@"ride_has_changed", @"") delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                            [_rideUIAlert show];
                        }
                    } else {
                        _rideUIAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"dialog_info_title", @"") message:NSLocalizedString(@"no_more_available_ride", @"") delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                        [_rideUIAlert show];
                        [self centerMapOnUserLocation];
                    }
                });
            });
                           
            /*dispatch_async(child, ^(void) {
                //[self createAllStationsAnnotations];
                if (_mapViewState == MAP_VIEW_SEARCH_STATE) {
                    dispatch_async(parent, ^(void) {
                        Station *selectedDeparture = _departureStation.copy;
                        Station *selectedArrival = _arrivalStation.copy;
                        BOOL isSameDeparture = true;
                        BOOL isSameArrival = true;
                        
                        [self eraseSearchAnnotations];
                        [self eraseRoute];
                        double radius = [self getDistanceBetweenDeparture:_departureLocation andArrival:_arrivalLocation withMin:STATION_SEARCH_MIN_RADIUS_IN_METERS withMax:STATION_SEARCH_MAX_RADIUS_IN_METERS];
                        [self searchCloseStationsAroundDeparture:_departureLocation withBikesNumber:[self.bikeField.text intValue] andMaxStationsNumber:SEARCH_RESULT_MAX_STATIONS_NUMBER inARadiusOf:radius];
                        [self searchCloseStationsAroundArrival:_arrivalLocation withAvailableStandsNumber:[self.standField.text intValue] andMaxStationsNumber:SEARCH_RESULT_MAX_STATIONS_NUMBER inARadiusOf:radius];
                        if (![self isTheSameStationBetween:selectedDeparture and:_departureStation]) {
                            isSameDeparture = false;
                            // user has selected another station than new one defined
                            for (Station *temp in _departureCloseStations) {
                                if ([self isTheSameStationBetween:selectedDeparture and:temp]) {
                                    NSLog(@"set departure station to user initial choice");
                                    _departureStation = temp;
                                    isSameDeparture = true;
                                    break;
                                }
                            }
                        }
                        if (![self isTheSameStationBetween:selectedArrival and:_arrivalStation]) {
                            isSameArrival = false;
                            // user has selected another station than new one defined
                            for (Station *temp in _arrivalCloseStations) {
                                if ([self isTheSameStationBetween:selectedArrival and:temp]) {
                                    NSLog(@"set arrival station to user initial choice");
                                    _arrivalStation = temp;
                                    isSameArrival = true;
                                    break;
                                }
                            }
                        }
                        if (_rideUIAlert != nil) {
                            [_rideUIAlert dismissWithClickedButtonIndex:0 animated:YES];
                        }
                        if ([_departureCloseStations count] > 0 && [_arrivalCloseStations count] > 0 && _departureStation != nil && _arrivalStation != nil) {
                            [self drawSearchAnnotations];
                            [self drawRouteFromStationDeparture:_departureStation toStationArrival:_arrivalStation];
                            if (!isSameDeparture || !isSameArrival) {
                                _rideUIAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"dialog_info_title", @"") message:NSLocalizedString(@"ride_has_changed", @"") delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                                [_rideUIAlert show];
                            }
                        } else {
                            _rideUIAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"dialog_info_title", @"") message:NSLocalizedString(@"no_more_available_ride", @"") delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                            [_rideUIAlert show];
                            [self centerMapOnUserLocation];
                        }
                    });
                }
            });*/
        }
        [self startTimer];
    }];
    [_jcdRequest handleExceptionWith:^(NSError *exception) {
        if (exception.code == JCD_TIMED_OUT_REQUEST_EXCEPTION_CODE) {
            NSLog(@"jcd ws exception : expired request");
            if (_jcdRequestAttemptsNumber < 2) {
                [_jcdRequest call];
                _jcdRequestAttemptsNumber++;
            } else {
                [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"dialog_error_title", @"") message:NSLocalizedString(@"jcd_ws_get_data_error", @"") delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
            }
        } else {
            NSLog(@"JCD ws exception %@", exception.debugDescription);
            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"dialog_error_title", @"") message:NSLocalizedString(@"jcd_ws_get_data_error", @"") delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
        }
    }];
    [_jcdRequest handleErrorWith:^(int errorCode) {
        NSLog(@"JCD ws error %d", errorCode);
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"dialog_error_title", @"") message:NSLocalizedString(@"jcd_ws_get_data_error", @"") delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
    }];
    
    NSLog(@"call ws");
    [_jcdRequest call];
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
        _currentZoomLevel = [UIUtils zoomLevel:mapPanel];
    }
}

# pragma mark Delegate

- (void)mapView:(MKMapView *)aMapView didUpdateUserLocation:(MKUserLocation *)aUserLocation {
    if ([self isEqualToLocationZero:_startUserLocation]) {
        NSLog(@"receive user location update (%f,%f)", aUserLocation.location.coordinate.latitude, aUserLocation.location.coordinate.longitude);
        if (![self isEqualToLocationZero:aUserLocation.location.coordinate]) {
            _startUserLocation = aUserLocation.location.coordinate;
            [self centerMapOnUserLocation];
            
            _departureAutocompleteView = [TRAutocompleteView autocompleteViewBindedTo:departureField usingSource:[[TRGoogleMapsAutocompleteItemsSource alloc] initWithMinimumCharactersToTrigger:3 withApiKey:KEY_GOOGLE_PLACES andUserLocation:_startUserLocation]cellFactory:[[TRGoogleMapsAutocompletionCellFactory alloc] initWithCellForegroundColor:[UIColor lightGrayColor] fontSize:14] presentingIn:self];
            _departureAutocompleteView.topMargin = -65;
            _departureAutocompleteView.backgroundColor = [UIUtils colorWithHexaString:@"#FFFFFF"];
            _departureAutocompleteView.didAutocompleteWith = ^(id<TRSuggestionItem> item)
            {
                NSLog(@"Departure autocompleted with: %@", item.completionText);
            };
            
            _arrivalAutocompleteView = [TRAutocompleteView autocompleteViewBindedTo:arrivalField usingSource:[[TRGoogleMapsAutocompleteItemsSource alloc] initWithMinimumCharactersToTrigger:3 withApiKey:KEY_GOOGLE_PLACES andUserLocation:_startUserLocation]cellFactory:[[TRGoogleMapsAutocompletionCellFactory alloc] initWithCellForegroundColor:[UIColor lightGrayColor] fontSize:14] presentingIn:self];
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
    if (!_isMapLoaded) {
        NSLog(@"map is loaded");
        _isMapLoaded = true;
        _isStationsDisplayedAtLeastOnce = false;
    }
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
            PlaceAnnotation *annotation = (PlaceAnnotation *) anAnnotation;

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
        } else if ([anAnnotation isKindOfClass:[ClusterAnnotation class]]) {
            ClusterAnnotation *cluster = (ClusterAnnotation *) anAnnotation;
            annotationID = @"Cluster";
            annotationView = (MKPinAnnotationView *)[aMapView dequeueReusableAnnotationViewWithIdentifier:annotationID];
            if (annotationView == nil) {
                annotationView = [[MKPinAnnotationView alloc] initWithAnnotation:cluster reuseIdentifier:annotationID];
                annotationView.image =  [UIImage imageNamed:@"Images/MapPanel/MPCluster"];
                //NSLog(@"create");
            } else {
                //NSLog(@"reuse");
            }
        }
        annotationView.canShowCallout = YES;
    }
    return annotationView;
}

- (void)mapView:(MKMapView *)aMapView didSelectAnnotationView:(MKAnnotationView *)aView {
    if (!_isSearchViewVisible && _mapViewState == MAP_VIEW_SEARCH_STATE) {
        if ([aView.annotation isKindOfClass:[PlaceAnnotation class]]) {
            PlaceAnnotation *annotation = (PlaceAnnotation *) aView.annotation;
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

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
    if (_isMapLoaded && _mapViewState == MAP_VIEW_DEFAULT_STATE && _isStationsDisplayedAtLeastOnce) {
        NSUInteger level = [UIUtils zoomLevel:mapPanel];
        if (level < _currentZoomLevel) {
            _currentZoomLevel = level;
            _isZoomIn = false;
            _isZoomOut = true;
            NSLog(@"zoom out");
        } else if (_currentZoomLevel < level) {
            _currentZoomLevel = level;
            _isZoomIn = true;
            _isZoomOut = false;
            NSLog(@"zoom in");
        } else {
            _isZoomIn = false;
            _isZoomOut = false;
        }
        //[self drawStationsAnnotationsWithReset:false];
        //dispatch_queue_t parent = dispatch_get_main_queue();
        //dispatch_queue_t child = dispatch_queue_create("com.onelightstudio.onebike", NULL);
        dispatch_async(oneBikeQueue, ^(void) {
            [self filterStationsAnnotationsWithReset:false];
            dispatch_async(uiQueue, ^(void) {
                [mapPanel removeAnnotations:_clustersAnnotationsToRemove];
                [mapPanel removeAnnotations:_stationsAnnotationsToRemove];
                [mapPanel addAnnotations:_clustersAnnotationsToAdd];
                [mapPanel addAnnotations:_stationsAnnotationsToAdd];
                [_stationsAnnotationsToRemove addObjectsFromArray:_stationsAnnotationsToAdd];
                [_stationsAnnotationsToAdd removeAllObjects];
                [_clustersAnnotationsToRemove removeAllObjects];
                [_clustersAnnotationsToRemove addObjectsFromArray:_clustersAnnotationsToAdd];
                [_clustersAnnotationsToAdd removeAllObjects];
                if (!_isStationsDisplayedAtLeastOnce) {
                    _isStationsDisplayedAtLeastOnce = true;
                }
            });
        });
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
    [_jcdRequest call];
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
        //dispatch_queue_t parent = dispatch_get_main_queue();
        //dispatch_queue_t child = dispatch_queue_create("com.onelightstudio.onebike", NULL);
        /*dispatch_async(child, ^(void) {
            // necessary time to trigger effective zoom
            [NSThread sleepForTimeInterval:1.0f];
            dispatch_async(parent, ^(void) {
                [self drawStationsAnnotationsWithReset:true];
            });
        });*/
        dispatch_async(oneBikeQueue, ^(void) {
            [self filterStationsAnnotationsWithReset:true];
            dispatch_async(uiQueue, ^(void) {
                [mapPanel removeAnnotations:_clustersAnnotationsToRemove];
                [mapPanel removeAnnotations:_stationsAnnotationsToRemove];
                [mapPanel addAnnotations:_clustersAnnotationsToAdd];
                [mapPanel addAnnotations:_stationsAnnotationsToAdd];
                [_stationsAnnotationsToRemove addObjectsFromArray:_stationsAnnotationsToAdd];
                [_stationsAnnotationsToAdd removeAllObjects];
                [_clustersAnnotationsToRemove removeAllObjects];
                [_clustersAnnotationsToRemove addObjectsFromArray:_clustersAnnotationsToAdd];
                [_clustersAnnotationsToAdd removeAllObjects];
                if (!_isStationsDisplayedAtLeastOnce) {
                    _isStationsDisplayedAtLeastOnce = true;
                }
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
                            double radius = [self getDistanceBetweenDeparture:_departureLocation andArrival:_arrivalLocation withMin:STATION_SEARCH_MIN_RADIUS_IN_METERS withMax:STATION_SEARCH_MAX_RADIUS_IN_METERS];
                            [self searchWithDeparture:_departureLocation andArrival:_arrivalLocation withBikes:[self.bikeField.text intValue] andAvailableStands:[self.standField.text intValue] inARadiusOf:radius];
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
                            double radius = [self getDistanceBetweenDeparture:_departureLocation andArrival:_arrivalLocation withMin:STATION_SEARCH_MIN_RADIUS_IN_METERS withMax:STATION_SEARCH_MAX_RADIUS_IN_METERS];
                            [self searchWithDeparture:_departureLocation andArrival:_arrivalLocation withBikes:[self.bikeField.text intValue] andAvailableStands:[self.standField.text intValue] inARadiusOf:radius];
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
            [_jcdRequest call];
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
    MKCoordinateRegion currentRegion = MKCoordinateRegionMakeWithDistance(_startUserLocation, SPAN_SIDE_INIT_LENGTH_IN_METERS, SPAN_SIDE_INIT_LENGTH_IN_METERS);
    [mapPanel setRegion:currentRegion animated:YES];
    NSLog(@"centered on user location (%f,%f)", _startUserLocation.latitude, _startUserLocation.longitude);
}

- (void)filterStationsAnnotationsWithReset:(BOOL)reset {
    if (!_isStationsDisplayedAtLeastOnce || reset) {
        [_clustersAnnotationsToRetain removeAllObjects];
        [_clustersAnnotationsToRemove removeAllObjects];
        [_stationsAnnotationsToRetain removeAllObjects];
        [_stationsAnnotationsToRemove removeAllObjects];
       _noClusterizedStations = [[NSMutableArray alloc] initWithArray:_allStations];
        
    }
    NSLog(@"no clusterized stations : %d", _noClusterizedStations.count);
    [self generateClustersAnnotationsWithZoomChanged:(_isZoomIn || _isZoomOut)];
}

- (void)generateClustersAnnotationsWithZoomChanged:(BOOL)hasZoomChanged {
    NSLog(@"generate clusters annotations, zoom level : %d", _currentZoomLevel);
    
    NSMutableArray *visibleStations = nil;
    NSMutableArray *drawableStations = nil;
    if (hasZoomChanged) {
        if (_isZoomIn) {
            NSLog(@"isZoomIn");
            _noClusterizedStations = [[NSMutableArray alloc] initWithArray:_allStations];
            visibleStations = [self filterVisibleStationsFrom:_noClusterizedStations];
            drawableStations = [[NSMutableArray alloc] initWithArray:visibleStations];
        } else if (_isZoomOut) {
            NSLog(@"isZoomOut");
            visibleStations = [self filterVisibleStationsFrom:_noClusterizedStations];
            drawableStations = [[NSMutableArray alloc] initWithArray:visibleStations];
        }
        [_clustersAnnotationsToRemove addObjectsFromArray:_clustersAnnotationsToRetain];
        [_clustersAnnotationsToRetain removeAllObjects];
        [_stationsAnnotationsToRemove addObjectsFromArray:_stationsAnnotationsToRetain];
        [_stationsAnnotationsToRetain removeAllObjects];
    } else {
        NSLog(@"noHasZoomChanged");
        visibleStations = [self filterVisibleStationsFrom:_noClusterizedStations];
        drawableStations = [[NSMutableArray alloc] initWithArray:visibleStations];
        [_clustersAnnotationsToRetain addObjectsFromArray:_clustersAnnotationsToRemove];
        [_clustersAnnotationsToRemove removeAllObjects];
        [_stationsAnnotationsToRetain addObjectsFromArray:_stationsAnnotationsToRemove];
        [_stationsAnnotationsToRemove removeAllObjects];
        NSLog(@"retained stations annotations : %d", _stationsAnnotationsToRetain.count);
        for (PlaceAnnotation *aStationAnnotation in _stationsAnnotationsToRetain) {
            if ([GeoUtils isLocation:aStationAnnotation.coordinate inRegion:mapPanel.region]) {
                NSLog(@"compare @%@ (%f,%f)", aStationAnnotation.placeStation.name, aStationAnnotation.placeStation.latitude.doubleValue, aStationAnnotation.placeStation.longitude.doubleValue);
                if ([visibleStations containsObject:aStationAnnotation.placeStation]) {
                    NSLog(@"remove @%@", aStationAnnotation.placeStation.name);
                    [drawableStations removeObject:aStationAnnotation.placeStation];
                }
            }
        }
    }
    //NSLog(@"drawable stations : %d", drawableStations.count);
    NSMutableArray *clusterizedStations = [[NSMutableArray alloc] init];
    if (visibleStations.count > 0) {
        NSMutableArray *temp = [[NSMutableArray alloc] initWithArray:visibleStations];
        double clusterSideLength = [GeoUtils getClusterSideLengthForZoomLevel:_currentZoomLevel];
        NSLog(@"clusters side length : %f m", clusterSideLength);
        //NSLog(@"clusterizable stations count : %d", clusterizablePlacesAnnotations.count);
        NSMutableArray *clusterStations;
        for (Station *base in visibleStations) {
            clusterStations = [[NSMutableArray alloc] init];
            //NSLog(@"buffer count : %d", temp.count);
            if ([temp containsObject:base]) {
                [temp removeObject:base];
                BOOL clusterized = false;
                for (int i = temp.count - 1; i >= 0; i--) {
                    Station *other = temp[i];
                    double currentDistance = [self getDistanceBetween:base and:other];
                    //NSLog(@"current distance : %f", currentDistance);
                    if (currentDistance < clusterSideLength) {
                        [clusterStations addObject:other];
                        [temp removeObjectAtIndex:i];
                        clusterized = true;
                    }
                }
                if (clusterized) {
                    [clusterStations addObject:base];
                    ClusterAnnotation *generated = [self createClusterAnnotationForStations:clusterStations];
                    [_clustersAnnotationsToAdd addObject:generated];
                    //NSLog(@"cluster annotation generated");
                    for (Station *aCusterizableStation in clusterStations) {
                        [temp removeObject:aCusterizableStation];
                    }
                    [clusterizedStations addObjectsFromArray:clusterStations];
                    //NSLog(@"convert %d stations into cluster", generated.children.count + 1);
                }
            }
        }
    }
    NSMutableArray *stationsAnnotationsToRemove = [[NSMutableArray alloc] init];
    NSLog(@"clusterized stations : %d", clusterizedStations.count);
    for (Station *aCusterizedStation in clusterizedStations) {
        if ([drawableStations containsObject:aCusterizedStation]) {
            NSLog(@"remove station @%@", aCusterizedStation.name);
            [drawableStations removeObject:aCusterizedStation];
            [_noClusterizedStations removeObject:aCusterizedStation];
        } else {
            int i = 0;
            for (PlaceAnnotation *aRetainedStationAnnotation in _stationsAnnotationsToRetain) {
                if ([GeoUtils isLocation:aRetainedStationAnnotation.coordinate inRegion:mapPanel.region]) {
                    i++;
                    NSLog(@"searching for relative existing annotation : %d / %d", i, _stationsAnnotationsToRetain.count);
                    //NSLog(@"compare station annotation @%@ (%f,%f)", aRetainedStationAnnotation.placeStation.name, aRetainedStationAnnotation.placeStation.latitude.doubleValue, aRetainedStationAnnotation.placeStation.longitude.doubleValue);
                    if ([aCusterizedStation isEqual:aRetainedStationAnnotation.placeStation]) {
                        [stationsAnnotationsToRemove addObject:aRetainedStationAnnotation];
                        break;
                    }
                }
            }
        }
    }
    if (stationsAnnotationsToRemove.count > 0) {
        // remove clusterized retained stations
        [_stationsAnnotationsToRemove addObjectsFromArray:stationsAnnotationsToRemove];
        for (PlaceAnnotation *aRetainedStationAnnotationToRemove in stationsAnnotationsToRemove) {
            NSLog(@"remove retained station annotation @%@", aRetainedStationAnnotationToRemove.placeStation.name);
            [_stationsAnnotationsToRetain removeObject:aRetainedStationAnnotationToRemove];
        }
        [stationsAnnotationsToRemove removeAllObjects];
    }
    NSLog(@"drawable stations : %d", drawableStations.count);
    for (Station *aDrawableStation in drawableStations) {
        if (_clustersAnnotationsToRetain.count > 0) {
            BOOL isCovered = false;
            for (ClusterAnnotation *existingCluster in _clustersAnnotationsToRetain) {
                // test if the station is already covered by an existing cluster
                if ([GeoUtils isLocation:aDrawableStation.coordinate inRegion:existingCluster.region]) {
                    NSLog(@"new station @%@ is already covered",aDrawableStation.name);
                    isCovered = true;
                    break;
                }
            }
            if (!isCovered) {
                NSLog(@"add new station @%@",aDrawableStation.name);
                [_stationsAnnotationsToAdd addObject:[self createStationAnnotation:aDrawableStation withLocation:kUndefined]];
            }
        } else {
            NSLog(@"add new station @%@",aDrawableStation.name);
            [_stationsAnnotationsToAdd addObject:[self createStationAnnotation:aDrawableStation withLocation:kUndefined]];
        }
    }
    NSLog(@"added clusters : %d", _clustersAnnotationsToAdd.count);
    NSLog(@"retained clusters : %d", _clustersAnnotationsToRetain.count);
    NSLog(@"removed clusters : %d", _clustersAnnotationsToRemove.count);
    NSLog(@"added stations : %d", _stationsAnnotationsToAdd.count);
    NSLog(@"retained station : %d", _stationsAnnotationsToRetain.count);
    NSLog(@"removed stations : %d", _stationsAnnotationsToRemove.count);
}

- (NSMutableArray *)filterVisibleStationsFrom:(NSMutableArray *)someStations {
    NSMutableArray *filteredStations = [[NSMutableArray alloc] init];
    for (Station *aStation in someStations) {
        if ([GeoUtils isLocation:aStation.coordinate inRegion:mapPanel.region]) {
            [filteredStations addObject:aStation];
        }
    }
    NSLog(@"visible stations : %d", filteredStations.count);
    return filteredStations;
}

/*- (void)createAllStationsAnnotations {
    NSLog(@"create all stations annotations");
    [self eraseAllStationsAnnotations];
    [_allStationsAnnotations removeAllObjects];
    int invalidStations = 0;
    int displayedStations = 0;
    for (Station *station in _allStations) {
        if (station.latitude != (id)[NSNull null] && station.longitude != (id)[NSNull null]) {
            [_allStationsAnnotations addObject:[self createStationAnnotation:station withLocation:kUndefined]];
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
}*/

/*- (void)drawStationsAnnotationsWithReset:(BOOL)reset {
    NSLog(@"draw stations");
    dispatch_queue_t parent = dispatch_get_main_queue();
    dispatch_queue_t child = dispatch_queue_create("com.onelightstudio.onebike", NULL);
    dispatch_async(child, ^(void) {
        [self filterStationsAnnotationsWithReset:reset];
        dispatch_async(parent, ^(void) {
            [mapPanel removeAnnotations:_clustersAnnotationsToRemove];
            [mapPanel removeAnnotations:_stationsAnnotationsToRemove];
            [mapPanel addAnnotations:_clustersAnnotationsToAdd];
            [mapPanel addAnnotations:_stationsAnnotationsToAdd];
            [_stationsAnnotationsToRemove addObjectsFromArray:_stationsAnnotationsToAdd];
            [_stationsAnnotationsToAdd removeAllObjects];
            [_clustersAnnotationsToRemove removeAllObjects];
            [_clustersAnnotationsToRemove addObjectsFromArray:_clustersAnnotationsToAdd];
            [_clustersAnnotationsToAdd removeAllObjects];
            if (!_isStationsDisplayedAtLeastOnce) {
                _isStationsDisplayedAtLeastOnce = true;
            }
        });
    });
}*/

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

- (PlaceAnnotation *)createStationAnnotation:(Station *)aStation withLocation:(PlaceAnnotationLocation)aLocation {
    
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

- (ClusterAnnotation *)createClusterAnnotationForStations:(NSMutableArray *)someStations {
    
    ClusterAnnotation *marker = [[ClusterAnnotation alloc] init];
    marker.region = MKCoordinateRegionForMapRect([self generateMapRectContainingAllStations:someStations]);
    marker.coordinate = marker.region.center;
    //marker.children = someStations;
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
            
            CLLocationCoordinate2D dep;
            dep.latitude = departure.latitude.doubleValue;
            dep.longitude = departure.longitude.doubleValue;
            
            CLLocationCoordinate2D arr;
            arr.latitude = arrival.latitude.doubleValue;
            arr.longitude = arrival.longitude.doubleValue;
            
            _route = [RoutePolyline routePolylineFromPolyline:[GeoUtils polylineWithEncodedString:encodedPolyline betweenDeparture:dep andArrival:arr]];
            [mapPanel addOverlay:_route];
            [mapPanel setVisibleMapRect:[self generateMapRectContainingAllAnnotations:_searchAnnotations] animated:YES];
            
        } else {
            NSLog(@"Google Maps API error %@", status);
            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"dialog_error_title", @"")  message:@"Google Maps API error" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
        }
        [self enableSearchButton];
    }];
    [googleRequest handleErrorWith:^(int errorCode) {
        NSLog(@"HTTP error %d", errorCode);
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"google_ws_search_ride_error", @"")  message:NSLocalizedString(@"OK", @"") delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
    }];
    [googleRequest handleExceptionWith:^(NSError *exception) {
        NSLog(@"Exception %@", exception.debugDescription);
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"google_ws_search_ride_error", @"")  message:NSLocalizedString(@"OK", @"") delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
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

/*- (void)eraseAllStationsAnnotations {
    if (_allStationsAnnotations != nil) {
        NSLog(@"erase all stations annotations");
        [mapPanel removeAnnotations:_allStationsAnnotations];
    }
}*/

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
    // CHECK
    // [self eraseAllStationsAnnotations];
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
        for (Station *station in _allStations) {
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
        for (Station *station in _allStations) {
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

-(double) getDistanceBetweenDeparture:(CLLocation *)departure andArrival:(CLLocation *)arrival withMin:(double)minRadius withMax:(double)maxRadius {
    double dist = [GeoUtils getDistanceFromLat:departure.coordinate.latitude toLat:arrival.coordinate.latitude fromLong:departure.coordinate.longitude toLong:arrival.coordinate.longitude];
    dist /= 2;
    if (dist > maxRadius) {
        dist = maxRadius;
    } else if (dist < minRadius) {
        dist = minRadius;
    }
    NSLog(@"max search radius : %f m", dist);
    return dist;
}

-(double) getDistanceBetween:(Station *)first and:(Station *)second {
    return [GeoUtils getDistanceFromLat:first.latitude.doubleValue toLat:second.latitude.doubleValue fromLong:first.longitude.doubleValue toLong:second.longitude.doubleValue];
}

- (BOOL)unlessInMeters:(double)radius from:(CLLocationCoordinate2D)origin for:(CLLocationCoordinate2D)location {
    double dist = [GeoUtils getDistanceFromLat:origin.latitude toLat:location.latitude fromLong:origin.longitude toLong:location.longitude];
    return dist <= radius;
}

- (MKMapRect)generateMapRectContainingAllAnnotations:(NSMutableArray*)annotations {
    
    MKMapRect mapRect = MKMapRectNull;
    for (id<MKAnnotation> annotation in annotations) {
        
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

- (MKMapRect)generateMapRectContainingAllStations:(NSMutableArray*)someStations {
    
    MKMapRect mapRect = MKMapRectNull;
    for (Station *aStation in someStations) {
        
        MKMapPoint annotationPoint = MKMapPointForCoordinate(aStation.coordinate);
        MKMapRect pointRect = MKMapRectMake(annotationPoint.x, annotationPoint.y, 0, 0);
        
        if (MKMapRectIsNull(mapRect)) {
            mapRect = pointRect;
        } else {
            mapRect = MKMapRectUnion(mapRect, pointRect);
        }
    }
    return mapRect;
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
