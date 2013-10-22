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
#import "Contract.h"

@interface MapController ()
    
@property (strong,readwrite) NSMutableArray *allContracts;
@property (strong,readwrite) NSMutableDictionary *cache;

@property (strong,readwrite) NSMutableArray *clustersAnnotationsToAdd;
@property (strong,readwrite) NSMutableArray *clustersAnnotationsToRemove;
@property (strong,readwrite) NSMutableArray *stationsAnnotationsToAdd;
@property (strong,readwrite) NSMutableArray *stationsAnnotationsToRemove;
@property (strong,readwrite) NSMutableArray *departureCloseStations;
@property (strong,readwrite) NSMutableArray *arrivalCloseStations;
@property (strong,readwrite) NSMutableArray *searchAnnotations;
@property (strong,readwrite) NSMutableArray *contractsAnnotations;

@property (strong,readwrite) TRAutocompleteView *departureAutocompleteView;
@property (strong,readwrite) TRAutocompleteView *arrivalAutocompleteView;
@property (strong,readwrite) UIAlertView *rideUIAlert;

@property (strong,readwrite) WSRequest *providerWSRequest;
@property (strong,readwrite) CLLocation *departureCLLocation;
@property (strong,readwrite) CLLocation *arrivalCLLocation;
@property (strong,readwrite) Station *departureStation;
@property (strong,readwrite) Station *arrivalStation;
@property (strong,readwrite) RoutePolyline *route;
@property (strong,readwrite) Contract *currentContract;
@property (strong,readwrite) NSNumber *isLocationServiceEnabled;
@property (strong,readwrite) NSTimer *timer;

@property (assign,readwrite) int mapViewState;
@property (assign,readwrite) int jcdRequestAttemptsNumber;
@property (assign,readwrite) int currentZoomLevel;
@property (assign,readwrite) BOOL isMapLoaded;
@property (assign,readwrite) BOOL searching;
@property (assign,readwrite) BOOL isSearchViewVisible;
@property (assign,readwrite) BOOL isZoomIn;
@property (assign,readwrite) BOOL isZoomOut;
@property (assign,readwrite) BOOL redraw;
@property (assign,readwrite) BOOL areContractsDrawn;
@property (assign,readwrite) CLLocationCoordinate2D startUserLocation;

@end

@implementation MapController {
    
    NSMutableArray *_allStations;
    
    dispatch_queue_t uiQueue;
    dispatch_queue_t oneBikeQueue;
}

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
    CLLocationCoordinate2D cc2d;
    cc2d.latitude = 0;
    cc2d.longitude = 0;
    self.startUserLocation = cc2d;
}

- (void)initView
{
    self.mapPanel.delegate = self;
    self.mapPanel.showsUserLocation = YES;
    [self.mapPanel addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapMap:)]];
    
    self.navigationItem.titleView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"NBLogo.png"]];
    
    CGRect searchFrame = self.searchPanel.frame;
    searchFrame.origin.y = -searchFrame.size.height;
    self.searchPanel.frame = searchFrame;
    
    UISwipeGestureRecognizer *swipeUpGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeUpInvoked:)];
    [swipeUpGestureRecognizer setDirection:UISwipeGestureRecognizerDirectionUp];
    [self.searchPanel addGestureRecognizer:swipeUpGestureRecognizer];
    
    self.bikeField.text = @"1";
    self.standField.text = @"1";
    self.cancelBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"NBClose.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(cancelBarButtonClicked:)];
    
    self.departureSpinner.hidesWhenStopped = YES;
    [self.departureSpinner setColor:[UIUtils colorWithHexaString:@"#b2ca04"]];
    self.arrivalSpinner.hidesWhenStopped = YES;
    [self.arrivalSpinner setColor:[UIUtils colorWithHexaString:@"#b2ca04"]];
    self.searchSpinner.hidesWhenStopped = YES;
    [self.searchSpinner setColor:[UIUtils colorWithHexaString:@"#ffffff"]];
    [self.searchSpinner setHidden:true];
    
    self.isMapLoaded = NO;
    [self resetUserLocation];
    self.mapViewState = MAP_VIEW_DEFAULT_STATE;
    self.isSearchViewVisible = NO;
    
    [self.infoBarButton setBackgroundImage:[UIImage new] forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    [self.searchBarButton setBackgroundImage:[UIImage new] forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    [self.cancelBarButton setBackgroundImage:[UIImage new] forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    
    UIImage *buttonBg = [[UIImage imageNamed:@"SPButtonBg.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(16, 16, 16, 16)];
    [self.searchButton setBackgroundImage:buttonBg forState:UIControlStateNormal];
    
    self.cache = [[NSMutableDictionary alloc] init];
    self.clustersAnnotationsToAdd = [[NSMutableArray alloc] init];
    self.clustersAnnotationsToRemove = [[NSMutableArray alloc] init];
    self.stationsAnnotationsToAdd = [[NSMutableArray alloc] init];
    self.stationsAnnotationsToRemove = [[NSMutableArray alloc] init];
    
    self.departureCloseStations = [[NSMutableArray alloc] init];
    self.arrivalCloseStations = [[NSMutableArray alloc] init];
    self.searchAnnotations = [[NSMutableArray alloc] init];
    self.contractsAnnotations = [[NSMutableArray alloc] init];
    
    self.rideUIAlert = nil;
    self.isZoomIn = NO;
    self.isZoomOut = NO;
    
    uiQueue = dispatch_get_main_queue();
    oneBikeQueue = dispatch_queue_create("com.onelightstudio.onebike", NULL);
    
    self.infoDistanceTextField.adjustsFontSizeToFitWidth = YES;
    self.infoDistanceTextField.minimumFontSize = 5.0;
    self.infoDurationTextField.adjustsFontSizeToFitWidth = YES;
    self.infoDurationTextField.minimumFontSize = 5.0;
    
    self.areContractsDrawn = NO;
    self.currentContract = nil;
}

- (void) startTimer {
    if (self.timer == nil)
    {
        NSLog(@"start timer");
        self.timer = [NSTimer scheduledTimerWithTimeInterval:TIME_BEFORE_REFRESH_DATA_IN_SECONDS target:self selector:@selector(timerFired:) userInfo:nil repeats:YES];
    }
}

- (void) stopTimer {
    if (self.timer != nil)
    {
        NSLog(@"stop timer");
        [self.timer invalidate];
        self.timer = nil;
    }
}

/*- (void)configureJCDWebServices {
    _jcdRequestAttemptsNumber = 0;
    NSLog(@"init jcd ws");
    _jcdRequest = [[WSRequest alloc] initWithResource:JCD_WS_ENTRY_POINT_PARAM_VALUE inBackground:_isStationsDisplayedAtLeastOnce];
    [_jcdRequest appendParameterWithKey:JCD_API_KEY_PARAM_NAME andValue:KEY_JCD];
    [_jcdRequest handleResultWith:^(id json) {
        NSLog(@"jcd ws result");
        _jcdRequestAttemptsNumber = 0;
        // block concurrent access
        dispatch_barrier_async(oneBikeQueue, ^(void) {
            _allStations = (NSMutableArray *)[Station fromJSONArray:json];
            NSLog(@"stations count %i", _allStations.count);
        });
        
        NSLog(@"draw stations");
        if (_mapViewState == MAP_VIEW_DEFAULT_STATE) {
            
            [self eraseAnnotations];
            
            dispatch_async(oneBikeQueue, ^(void) {
                [self generateStationsAnnotations];
                dispatch_async(uiQueue, ^(void) {
                    [mapPanel addAnnotations:_clustersAnnotationsToAdd];
                    [_clustersAnnotationsToRemove addObjectsFromArray:_clustersAnnotationsToAdd];
                    [_clustersAnnotationsToAdd removeAllObjects];
                    
                    [mapPanel addAnnotations:_stationsAnnotationsToAdd];
                    [_stationsAnnotationsToRemove addObjectsFromArray:_stationsAnnotationsToAdd];
                    [_stationsAnnotationsToAdd removeAllObjects];
                    
                    if (!_isStationsDisplayedAtLeastOnce) {
                        _isStationsDisplayedAtLeastOnce = true;
                    }
                });
            });
        } else if (_mapViewState == MAP_VIEW_SEARCH_STATE) {
            
            Station *selectedDeparture = _departureStation.copy;
            Station *selectedArrival = _arrivalStation.copy;
            
            [self eraseSearchAnnotations];
            [self eraseRoute];
            
            dispatch_async(oneBikeQueue, ^(void) {
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
}*/

- (void)loadContracts {
    NSError *error, *exception;
    NSString *path = [[NSBundle mainBundle] pathForResource:@"contracts" ofType:@"json"];
    NSLog(@"load contracts from @%@", path);
    NSString *content = [[NSString alloc] initWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    if (error == nil) {
        id json = [NSJSONSerialization JSONObjectWithData:[content dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&exception];
        if (exception == nil) {
            self.allContracts = (NSMutableArray *)[Contract fromJSONArray:json];
            NSLog(@"contracts found : %i", self.allContracts.count);
        } else {
            NSLog(@"exception occured during json contracts data processing  : %@", exception.debugDescription);
        }
    } else {
        NSLog(@"error occured during contracts json file loading  : %@", error.debugDescription);
    }
    
}

# pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0) {
        self.navigationController.navigationBar.translucent = NO;
    }
    
    [self registerOn];
    [self loadContracts];
    [self initView];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    [self stopTimer];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated
{
    if (!self.isMapLoaded) {
        // centered by default on Toulouse
        CLLocationCoordinate2D tls;
        tls.latitude = TLS_LAT;
        tls.longitude = TLS_LONG;
        
        MKCoordinateRegion viewRegion = MKCoordinateRegionMakeWithDistance(tls, SPAN_SIDE_INIT_LENGTH_IN_METERS, SPAN_SIDE_INIT_LENGTH_IN_METERS);
        [self.mapPanel setRegion:viewRegion animated:YES];
        NSLog(@"centered on Toulouse (%f,%f)", tls.latitude, tls.longitude);
        
        self.isLocationServiceEnabled = nil;
        if (![CLLocationManager locationServicesEnabled]) {
            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"dialog_warning_title", @"") message:NSLocalizedString(@"no_location_activated", @"") delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil] show];
            self.isLocationServiceEnabled = [NSNumber numberWithBool:NO];
        } else if ([CLLocationManager authorizationStatus] != kCLAuthorizationStatusNotDetermined && [CLLocationManager authorizationStatus] != kCLAuthorizationStatusAuthorized) {
            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"dialog_warning_title", @"") message:NSLocalizedString(@"no_location_allowed", @"") delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil] show];
            self.isLocationServiceEnabled = [NSNumber numberWithBool:NO];
        } else if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorized) {
            self.isLocationServiceEnabled = [NSNumber numberWithBool:YES];
        }
        self.currentZoomLevel = [UIUtils zoomLevel:self.mapPanel];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    if (!self.searching) {
        [self enableSearchButton];
    } else {
        [self disableSearchButton];
    }
}

# pragma mark Delegate

- (void)mapView:(MKMapView *)aMapView didUpdateUserLocation:(MKUserLocation *)aUserLocation {
    if ([self isEqualToLocationZero:self.startUserLocation]) {
        NSLog(@"receive user location update (%f,%f)", aUserLocation.location.coordinate.latitude, aUserLocation.location.coordinate.longitude);
        if (![self isEqualToLocationZero:aUserLocation.location.coordinate]) {
            self.startUserLocation = aUserLocation.location.coordinate;
            [self centerMapOnUserLocation];
            
            self.departureAutocompleteView = [TRAutocompleteView autocompleteViewBindedTo:self.departureField usingSource:[[TRGoogleMapsAutocompleteItemsSource alloc] initWithMinimumCharactersToTrigger:3 withApiKey:KEY_GOOGLE_PLACES andUserLocation:self.startUserLocation]cellFactory:[[TRGoogleMapsAutocompletionCellFactory alloc] initWithCellForegroundColor:[UIColor lightGrayColor] fontSize:14] presentingIn:self];
            self.departureAutocompleteView.topMargin = -65;
            self.departureAutocompleteView.backgroundColor = [UIUtils colorWithHexaString:@"#FFFFFF"];
            self.departureAutocompleteView.didAutocompleteWith = ^(id<TRSuggestionItem> item)
            {
                NSLog(@"Departure autocompleted with: %@", item.completionText);
            };
            
            self.arrivalAutocompleteView = [TRAutocompleteView autocompleteViewBindedTo:self.arrivalField usingSource:[[TRGoogleMapsAutocompleteItemsSource alloc] initWithMinimumCharactersToTrigger:3 withApiKey:KEY_GOOGLE_PLACES andUserLocation:self.startUserLocation]cellFactory:[[TRGoogleMapsAutocompletionCellFactory alloc] initWithCellForegroundColor:[UIColor lightGrayColor] fontSize:14] presentingIn:self];
            self.arrivalAutocompleteView.topMargin = -65;
            self.arrivalAutocompleteView.backgroundColor = [UIUtils colorWithHexaString:@"#FFFFFF"];
            self.arrivalAutocompleteView.didAutocompleteWith = ^(id<TRSuggestionItem> item)
            {
                NSLog(@"Arrival autocompleted with: %@", item.completionText);
            };
        }
    }
}

- (void)mapViewDidFinishLoadingMap:(MKMapView *)aMapView {
    if (!self.isMapLoaded) {
        NSLog(@"map is loaded");
        self.isMapLoaded = true;
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
    MKAnnotationView *annotationView;
    static NSString *annotationID;
    
    if (anAnnotation != self.mapPanel.userLocation) {
        if ([anAnnotation isKindOfClass:[PlaceAnnotation class]]) {
            PlaceAnnotation *annotation = (PlaceAnnotation *) anAnnotation;

            if (annotation.placeType == kDeparture) {
                annotationID = @"Departure";
                annotationView = (MKAnnotationView *)[aMapView dequeueReusableAnnotationViewWithIdentifier:annotationID];
                if (annotationView == nil) {
                    annotationView = [[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:annotationID];
                    annotationView.image =  [UIImage imageNamed:@"MPDeparture.png"];
                }
            } else if (annotation.placeType == kArrival) {
                annotationID = @"Arrival";
                annotationView = (MKAnnotationView *)[aMapView dequeueReusableAnnotationViewWithIdentifier:annotationID];
                if (annotationView == nil) {
                    annotationView = [[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:annotationID];
                    annotationView.image =  [UIImage imageNamed:@"MPArrival.png"];
                }
            } else {
                NSMutableString *loc = [[NSMutableString alloc] initWithString:[annotation.placeStation.latitude stringValue]];
                [loc appendString:@","];
                [loc appendString:[annotation.placeStation.longitude stringValue]];
                annotationID = [NSString stringWithString:loc];
                annotationView = (MKAnnotationView *)[aMapView dequeueReusableAnnotationViewWithIdentifier:annotationID];
                if (annotationView == nil) {
                    annotationView = [[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:annotationID];
                    annotationView.centerOffset = CGPointMake(0.0, -15.0);
                }
                UIImage *background = [UIImage imageNamed:@"MPStation.png"];
                UIImage *bikes = [UIUtils drawBikesText:[annotation.placeStation.availableBikes stringValue]];
                UIImage *tmp = [UIUtils placeBikes:bikes onImage:background];
                UIImage *stands = [UIUtils drawStandsText:[annotation.placeStation.availableBikeStands stringValue]];
                UIImage *image = [UIUtils placeStands:stands onImage:tmp];
                annotationView.image = image;
            }
            annotationView.canShowCallout = YES;
        } else if ([anAnnotation isKindOfClass:[ClusterAnnotation class]]) {
            ClusterAnnotation *cluster = (ClusterAnnotation *) anAnnotation;
            annotationID = @"Cluster";
            annotationView = (MKAnnotationView *)[aMapView dequeueReusableAnnotationViewWithIdentifier:annotationID];
            if (annotationView == nil) {
                annotationView = [[MKAnnotationView alloc] initWithAnnotation:cluster reuseIdentifier:annotationID];
                annotationView.image =  [UIImage imageNamed:@"MPCluster.png"];
                annotationView.centerOffset = CGPointMake(0.0, -15.0);
            }
            annotationView.canShowCallout = NO;
        }
    }
    return annotationView;
}

- (void)mapView:(MKMapView *)aMapView didSelectAnnotationView:(MKAnnotationView *)aView {
    if (self.mapViewState == MAP_VIEW_DEFAULT_STATE) {
        if ([aView.annotation isKindOfClass:[ClusterAnnotation class]]) {
            ClusterAnnotation *annotation = (ClusterAnnotation *) aView.annotation;
            // zoom in on cluster region
            [self.mapPanel setRegion:annotation.region animated:YES];
            dispatch_async(oneBikeQueue, ^(void) {
                [self generateStationsAnnotations];
                dispatch_async(uiQueue, ^(void) {
                    [self.mapPanel addAnnotations:self.clustersAnnotationsToAdd];
                    [self.clustersAnnotationsToRemove addObjectsFromArray:self.clustersAnnotationsToAdd];
                    [self.clustersAnnotationsToAdd removeAllObjects];
                    
                    [self.mapPanel addAnnotations:self.stationsAnnotationsToAdd];
                    [self.stationsAnnotationsToRemove addObjectsFromArray:self.stationsAnnotationsToAdd];
                    [self.stationsAnnotationsToAdd removeAllObjects];
                });
            });
        }
    } else if (!self.isSearchViewVisible && self.mapViewState == MAP_VIEW_SEARCH_STATE) {
        if ([aView.annotation isKindOfClass:[PlaceAnnotation class]] && !_redraw) {
            PlaceAnnotation *annotation = (PlaceAnnotation *) aView.annotation;
            if (annotation.placeType != kDeparture && annotation.placeType != kArrival && annotation.placeLocation != kUndefined) {
                if (annotation.placeLocation == kNearDeparture && self.departureStation != annotation.placeStation) {
                    NSLog(@"change departure");
                    self.departureStation = annotation.placeStation;
                    self.redraw = YES;
                } else if (annotation.placeLocation == kNearArrival && self.arrivalStation != annotation.placeStation) {
                    NSLog(@"change arrival");
                    self.arrivalStation = annotation.placeStation;
                    self.redraw = YES;
                } else {
                    self.redraw = NO;
                }
                if (self.redraw) {
                    [self eraseRoute];
                    [self drawRouteFromStationDeparture:self.departureStation toStationArrival:self.arrivalStation];
                }
            }
        }
    }
    
}

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
    if (self.isMapLoaded && self.mapViewState == MAP_VIEW_DEFAULT_STATE) {
        NSUInteger level = [UIUtils zoomLevel:self.mapPanel];
        if (level < self.currentZoomLevel) {
            self.currentZoomLevel = level;
            self.isZoomIn = NO;
            self.isZoomOut = YES;
            NSLog(@"zoom out");
        } else if (self.currentZoomLevel < level) {
            self.currentZoomLevel = level;
            self.isZoomIn = YES;
            self.isZoomOut = NO;
            NSLog(@"zoom in");
        } else {
            self.isZoomIn = NO;
            self.isZoomOut = NO;
        }

        if (self.currentZoomLevel < 10) {
            // use contracts data
            if (self.contractsAnnotations.count == 0) {
                [self generateContractsAnnotations];
            }
            [self drawContractsAnnotations];
        } else {
            [self eraseContractsAnnotations];
            [self eraseAnnotations];
            [self setCurrentContract];
            if (self.currentContract != nil) {
                if (![[self.cache allKeys] containsObject:self.currentContract.name]) {
                    switch (self.currentContract.provider) {
                        case kJCDecaux:
                            {
                                self.jcdRequestAttemptsNumber = 0;
                                NSLog(@"call JCD ws for contract : %@", self.currentContract.name);
                                self.providerWSRequest = [[WSRequest alloc] initWithResource:JCD_WS_ENTRY_POINT_PARAM_VALUE inBackground:NO];
                                [self.providerWSRequest appendParameterWithKey:JCD_CONTRACT_KEY_PARAM_NAME andValue:self.currentContract.name];
                                [self.providerWSRequest appendParameterWithKey:JCD_API_KEY_PARAM_NAME andValue:KEY_JCD];
                                [self.providerWSRequest handleResultWith:^(id json) {
                                    NSLog(@"JCD ws result");
                                    NSMutableArray *contractStations = (NSMutableArray *)[Station fromJSONArray:json];
                                    NSLog(@"%@ has %i stations", self.currentContract.name, contractStations.count);
                                    [self.cache setObject:contractStations forKey:self.currentContract.name];
                                    [self drawAnnotations];
                                }];
                                [self.providerWSRequest handleExceptionWith:^(NSError *exception) {
                                    if (exception.code == JCD_TIMED_OUT_REQUEST_EXCEPTION_CODE) {
                                        NSLog(@"jcd ws exception : expired request");
                                        if (self.jcdRequestAttemptsNumber < 2) {
                                            [self.providerWSRequest call];
                                            self.jcdRequestAttemptsNumber++;
                                        } else {
                                            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"dialog_error_title", @"") message:NSLocalizedString(@"jcd_ws_get_data_error", @"") delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
                                        }
                                    } else {
                                        NSLog(@"JCD ws exception %@", exception.debugDescription);
                                        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"dialog_error_title", @"") message:NSLocalizedString(@"jcd_ws_get_data_error", @"") delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
                                    }
                                }];
                                [self.providerWSRequest handleErrorWith:^(int errorCode) {
                                    NSLog(@"JCD ws error %d", errorCode);
                                    [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"dialog_error_title", @"") message:NSLocalizedString(@"jcd_ws_get_data_error", @"") delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
                                }];
                                [self.providerWSRequest call];
                            }
                            break;
                        case kCityBikes:
                        default:
                            break;
                    }
                } else {
                    [self drawAnnotations];
                }
            }
        }
    }
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField {
    if (textField == self.departureField) {
        [self.departureAutocompleteView hide];
    } else if (textField == self.arrivalField) {
        [self.arrivalAutocompleteView hide];
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
    [self.providerWSRequest call];
}

- (void)didTapMap:(UITapGestureRecognizer *)sender
{
    NSLog(@"tap map fired");
    if (self.isSearchViewVisible) {
        self.isSearchViewVisible = NO;
        [self closeSearchPanel];
    }
    [self refreshNavigationBarHasSearchView:self.isSearchViewVisible hasRideView:self.mapViewState == MAP_VIEW_SEARCH_STATE];
}

- (IBAction)searchBarButtonClicked:(id)sender {
    self.isSearchViewVisible = YES;
    [self openSearchPanel];
    [self refreshNavigationBarHasSearchView:self.isSearchViewVisible hasRideView:self.mapViewState == MAP_VIEW_SEARCH_STATE];
}

- (IBAction)cancelBarButtonClicked:(id)sender {
    if (self.isSearchViewVisible) {
        self.isSearchViewVisible = NO;
        [self closeSearchPanel];
    } else {
        self.mapViewState = MAP_VIEW_DEFAULT_STATE;
        [self resetSearchViewFields];
        [self eraseRoute];
        [self eraseSearchAnnotations];
        [self centerMapOnUserLocation];
        dispatch_async(oneBikeQueue, ^(void) {
            // necessary time to trigger effective zoom (and avoid to consider too many visible stations in map region)
            [NSThread sleepForTimeInterval:1.5f];
            [self generateStationsAnnotations];
            dispatch_async(uiQueue, ^(void) {
                [self.mapPanel addAnnotations:self.clustersAnnotationsToAdd];
                [self.clustersAnnotationsToRemove addObjectsFromArray:self.clustersAnnotationsToAdd];
                [self.clustersAnnotationsToAdd removeAllObjects];
                
                [self.mapPanel addAnnotations:self.stationsAnnotationsToAdd];
                [self.stationsAnnotationsToRemove addObjectsFromArray:self.stationsAnnotationsToAdd];
                [self.stationsAnnotationsToAdd removeAllObjects];
            });
        });
        [self.infoPanel setHidden:true];
    }
    [self refreshNavigationBarHasSearchView:self.isSearchViewVisible hasRideView:self.mapViewState == MAP_VIEW_SEARCH_STATE];
}

- (IBAction)backBarButtonClicked:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)departureFieldChanged:(id)sender {
    if (self.departureField.text.length < 3) {
        [self.departureAutocompleteView hide];
    }
}

- (IBAction)arrivalFieldChanged:(id)sender {
    if (self.arrivalField.text.length < 3) {
        [self.arrivalAutocompleteView hide];
    }
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
        if (![self.departureAutocompleteView isHidden]) {
            [self.departureAutocompleteView hide];
        }
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
        if (![self.arrivalAutocompleteView isHidden]) {
            [self.arrivalAutocompleteView hide];
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
        [self disableSearchButton];
        self.departureCLLocation = nil;
        self.arrivalCLLocation = nil;
        [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
        CLGeocoder *departureGeocoder = [[CLGeocoder alloc] init];
        CLGeocoder *arrivalGeocoder = [[CLGeocoder alloc] init];
        [departureGeocoder geocodeAddressString:self.departureField.text inRegion:nil completionHandler:^(NSArray *placemarks, NSError *error) {
            if (self.searching) {
                if (error != nil) {
                    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                    [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"dialog_error_title", @"") message:NSLocalizedString(@"departure_not_found", @"") delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil] show];
                   [self enableSearchButton];
                } else {
                    self.departureCLLocation = [(CLPlacemark *)[placemarks objectAtIndex:0] location];
                    if (self.departureCLLocation != nil && self.arrivalCLLocation != nil) {
                        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                        if (![self areEqualLocationsBetween:self.departureCLLocation and:self.arrivalCLLocation]) {
                            if (_allStations != nil) {
                                [self cancelBarButtonClicked:nil];
                                double radius = [self getDistanceBetweenDeparture:self.departureCLLocation andArrival:self.arrivalCLLocation withMin:STATION_SEARCH_MIN_RADIUS_IN_METERS withMax:STATION_SEARCH_MAX_RADIUS_IN_METERS];
                                [self searchWithDeparture:self.departureCLLocation andArrival:self.arrivalCLLocation withBikes:[self.bikeField.text intValue] andAvailableStands:[self.standField.text intValue] inARadiusOf:radius];
                            } else {
                                [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"dialog_warning_title", @"")  message:NSLocalizedString(@"jcd_ws_get_data_warning", @"") delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
                            }
                        } else {
                            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"dialog_warning_title", @"")  message:NSLocalizedString(@"same_location", @"") delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
                            [self enableSearchButton];
                        }
                    }
                }
            }
        }];
        [arrivalGeocoder geocodeAddressString:self.arrivalField.text inRegion:nil completionHandler:^(NSArray *placemarks, NSError *error) {
            if (self.searching) {
                if (error != nil) {
                    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                    [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"dialog_error_title", @"") message:NSLocalizedString(@"arrival_not_found", @"") delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil] show];
                    [self enableSearchButton];
                } else {
                    self.arrivalCLLocation = [(CLPlacemark *)[placemarks objectAtIndex:0] location];
                    if (self.departureCLLocation != nil && self.arrivalCLLocation != nil) {
                        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                        if (![self areEqualLocationsBetween:self.departureCLLocation and:self.arrivalCLLocation]) {
                            if (_allStations != nil) {
                                [self cancelBarButtonClicked:nil];
                                double radius = [self getDistanceBetweenDeparture:self.departureCLLocation andArrival:self.arrivalCLLocation withMin:STATION_SEARCH_MIN_RADIUS_IN_METERS withMax:STATION_SEARCH_MAX_RADIUS_IN_METERS];
                                [self searchWithDeparture:self.departureCLLocation andArrival:self.arrivalCLLocation withBikes:[self.bikeField.text intValue] andAvailableStands:[self.standField.text intValue] inARadiusOf:radius];
                            } else {
                               [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"dialog_warning_title", @"")  message:NSLocalizedString(@"jcd_ws_get_data_warning", @"") delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show]; 
                            }
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

- (void)swipeUpInvoked:(UITapGestureRecognizer *)recognizer {
    if (self.isSearchViewVisible) {
        self.isSearchViewVisible = NO;
        [self closeSearchPanel];
    }
    [self refreshNavigationBarHasSearchView:self.isSearchViewVisible hasRideView:self.mapViewState == MAP_VIEW_SEARCH_STATE];
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
            [self.providerWSRequest call];
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
    MKCoordinateRegion currentRegion = MKCoordinateRegionMakeWithDistance(self.startUserLocation, SPAN_SIDE_INIT_LENGTH_IN_METERS, SPAN_SIDE_INIT_LENGTH_IN_METERS);
    [self.mapPanel setRegion:currentRegion animated:YES];
    NSLog(@"centered on user location (%f,%f)", self.startUserLocation.latitude, self.startUserLocation.longitude);
}

- (void)generateContractsAnnotations {
    NSLog(@"generate contracts annotations");
    for (Contract *contract in self.allContracts) {
        [self.contractsAnnotations addObject:[self createContractAnnotation:contract]];
    }
    NSLog(@"generated contracts : %d", self.contractsAnnotations.count);
}

- (void)generateStationsAnnotations {
    NSLog(@"generate clusters annotations, zoom level : %d", self.currentZoomLevel);
    NSMutableArray *visibleStations = [self filterVisibleStationsFrom:[self.cache objectForKey:_currentContract.name]];
    
    double clusterSideLength = [GeoUtils getClusterSideLengthForZoomLevel:self.currentZoomLevel];
    NSLog(@"clusters side length : %f m", clusterSideLength);
    
    NSMutableArray *temp = [[NSMutableArray alloc] initWithArray:visibleStations];
    NSMutableArray *clusterStations;
    
    for (Station *base in visibleStations) {
        clusterStations = [[NSMutableArray alloc] init];
        if ([temp containsObject:base]) {
            [temp removeObject:base];
            BOOL clusterized = false;
            for (int i = temp.count - 1; i >= 0; i--) {
                Station *other = temp[i];
                double currentDistance = [self getStationDistanceBetween:base and:other];
                if (currentDistance < clusterSideLength) {
                    [clusterStations addObject:other];
                    [temp removeObjectAtIndex:i];
                    clusterized = true;
                }
            }
            if (clusterized) {
                [clusterStations addObject:base];
                ClusterAnnotation *newCluster = [self createClusterAnnotationForStations:clusterStations];
                [self.clustersAnnotationsToAdd addObject:newCluster];
                NSLog(@"convert %d stations into new cluster", clusterStations.count);
            } else {
                PlaceAnnotation *newStation = [self createStationAnnotation:base withLocation:kUndefined];
                NSLog(@"add new station @%@", newStation.placeStation.name);
                [self.stationsAnnotationsToAdd addObject:newStation];
            }
        }
    }
    NSLog(@"added stations : %d", self.stationsAnnotationsToAdd.count);
    NSLog(@"added clusters : %d", self.clustersAnnotationsToAdd.count);
}

- (NSMutableArray *)filterVisibleStationsFrom:(NSMutableArray *)someStations {
    NSMutableArray *filteredStations = [[NSMutableArray alloc] init];
    for (Station *aStation in someStations) {
        if ([GeoUtils isLocation:aStation.coordinate inRegion:self.mapPanel.region]) {
            [filteredStations addObject:aStation];
        }
    }
    NSLog(@"visible stations : %d", filteredStations.count);
    return filteredStations;
}

- (ClusterAnnotation *)createContractAnnotation:(Contract *)aContract {
    ClusterAnnotation *marker = [[ClusterAnnotation alloc] init];
    marker.region = aContract.region;
    marker.coordinate = marker.region.center;
    marker.title = @"";
    return marker;
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
    marker.region = [self generateRegionForDefaultMode:someStations];
    marker.coordinate = marker.region.center;
    marker.title = @"";
    return marker;
}

- (void)drawContractsAnnotations {
    if (!self.areContractsDrawn) {
        [self eraseAnnotations];
        NSLog(@"draw contracts annotations");
        [self.mapPanel addAnnotations:self.contractsAnnotations];
        NSLog(@"added contracts : %d", self.contractsAnnotations.count);
        self.areContractsDrawn = YES;
    }
}

-(void)drawAnnotations {
    dispatch_async(oneBikeQueue, ^(void) {
        [self generateStationsAnnotations];
        dispatch_async(uiQueue, ^(void) {
            [self.mapPanel addAnnotations:self.clustersAnnotationsToAdd];
            [self.clustersAnnotationsToRemove addObjectsFromArray:self.clustersAnnotationsToAdd];
            [self.clustersAnnotationsToAdd removeAllObjects];
            
            [self.mapPanel addAnnotations:self.stationsAnnotationsToAdd];
            [self.stationsAnnotationsToRemove addObjectsFromArray:self.stationsAnnotationsToAdd];
            [self.stationsAnnotationsToAdd removeAllObjects];
        });
    });
}

- (void)drawSearchAnnotations {
    
    NSLog(@"draw search annotations");
    Station *temp = nil;
    
    // departure annotation
    PlaceAnnotation *departureAnnotation = [[PlaceAnnotation alloc] init];
    departureAnnotation.placeType = kDeparture;
    departureAnnotation.coordinate = self.departureCLLocation.coordinate;
    departureAnnotation.title = self.departureField.text;
    temp = [[Station alloc] init];
    temp.latitude = [[NSNumber alloc] initWithDouble:self.departureCLLocation.coordinate.latitude];
    temp.longitude = [[NSNumber alloc] initWithDouble:self.departureCLLocation.coordinate.longitude];
    departureAnnotation.placeStation = temp;
    
    [self.searchAnnotations addObject:departureAnnotation];
    
    // arrival annotation
    PlaceAnnotation *arrivalAnnotation = [[PlaceAnnotation alloc] init];
    arrivalAnnotation.placeType = kArrival;
    arrivalAnnotation.coordinate = self.arrivalCLLocation.coordinate;
    arrivalAnnotation.title = self.arrivalField.text;
    temp = [[Station alloc] init];
    temp.latitude = [[NSNumber alloc] initWithDouble:self.arrivalCLLocation.coordinate.latitude];
    temp.longitude = [[NSNumber alloc] initWithDouble:self.arrivalCLLocation.coordinate.longitude];
    arrivalAnnotation.placeStation = temp;
    
    [self.searchAnnotations addObject:arrivalAnnotation];
    
    for (Station *station in self.departureCloseStations) {
        [self.searchAnnotations addObject:[self createStationAnnotation:station withLocation:kNearDeparture]];
    }
    for (Station *station in self.arrivalCloseStations) {
        [self.searchAnnotations addObject:[self createStationAnnotation:station withLocation:kNearArrival]];
    }
    [self.mapPanel addAnnotations:self.searchAnnotations];
}

- (void)drawRouteFromStationDeparture:(Station *)departure toStationArrival:(Station *)arrival {
    if (departure == arrival) {
        [self.mapPanel setRegion:[self generateRegionForSearchMode:self.searchAnnotations] animated:YES];
        [[[UIAlertView alloc] initWithTitle:nil message:NSLocalizedString(@"same_station", @"") delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
        return;
    }
    
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
            
            NSString *distanceLabel = [[[[[[json objectForKey:@"routes"] firstObject] objectForKey:@"legs"] firstObject] objectForKey:@"distance"] objectForKey:@"text"];
            NSInteger duration = ((NSString *)[[[[[[json objectForKey:@"routes"] firstObject] objectForKey:@"legs"] firstObject] objectForKey:@"duration"] objectForKey:@"value"]).integerValue / 2;
            NSMutableString *durationLabel = nil;
            NSLog(@"duration : %i s", duration);
            NSLog(@"distance label : %@", distanceLabel);
            if (duration <= 3569) {
                int minutes = (int)round(((float) duration) / 60);
                NSLog(@"process minutes : %i", minutes);
                durationLabel = [NSMutableString stringWithFormat:@"%i min", minutes];
            } else {
                durationLabel = [[NSMutableString alloc] init];
                int hour = (int)floor(((float) duration) / 3600);
                NSLog(@"process hour : %i", hour);
                durationLabel = [NSMutableString stringWithFormat:@"%i h ", hour];
                float modulo = (float) (duration % 3600);
                int minutes = (int)round(modulo / 60);
                NSLog(@"process minutes : %i", minutes);
                if (minutes > 0) {
                    [durationLabel appendFormat:@"%i min", minutes];
                }
            }
            NSLog(@"duration label : %@", durationLabel);
            [self.infoPanel setHidden:false];
            [self.infoDistanceTextField setText:distanceLabel];
            [self.infoDurationTextField setText:durationLabel];
            
            CLLocationCoordinate2D dep;
            dep.latitude = departure.latitude.doubleValue;
            dep.longitude = departure.longitude.doubleValue;
            
            CLLocationCoordinate2D arr;
            arr.latitude = arrival.latitude.doubleValue;
            arr.longitude = arrival.longitude.doubleValue;
            
            self.route = [RoutePolyline routePolylineFromPolyline:[GeoUtils polylineWithEncodedString:encodedPolyline betweenDeparture:dep andArrival:arr]];
            [self.mapPanel addOverlay:self.route];
            [self.mapPanel setRegion:[self generateRegionForSearchMode:self.searchAnnotations] animated:YES];
            self.redraw = NO;
            
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

- (void)eraseContractsAnnotations {
    [self.mapPanel removeAnnotations:self.contractsAnnotations];
    self.areContractsDrawn = NO;
}

- (void)eraseAnnotations
{
    NSLog(@"removed stations : %d", self.stationsAnnotationsToRemove.count);
    NSLog(@"removed clusters : %d", self.clustersAnnotationsToRemove.count);
    [self.mapPanel removeAnnotations:self.clustersAnnotationsToRemove];
    [self.clustersAnnotationsToRemove removeAllObjects];
    [self.mapPanel removeAnnotations:self.stationsAnnotationsToRemove];
    [self.stationsAnnotationsToRemove removeAllObjects];
}

- (void)eraseRoute {
    if (self.route != nil) {
        NSLog(@"erase route");
        [self.mapPanel removeOverlay:self.route];
        self.route = nil;
    }
}

- (void)eraseSearchAnnotations {
    if (self.searchAnnotations != nil) {
        NSLog(@"erase search annotations");
        [self.mapPanel removeAnnotations:self.searchAnnotations];
        [self.searchAnnotations removeAllObjects];
        [self.departureCloseStations removeAllObjects];
        [self.arrivalCloseStations removeAllObjects];
        self.departureStation = nil;
        self.arrivalStation = nil;
    }
}

# pragma mark Search panel

- (void)enableSearchButton {
     self.searching = NO;
    self.searchButton.enabled = true;
    [self.searchButton setTitle:NSLocalizedString(@"7ZO-mt-kun.normalTitle", @"") forState:UIControlStateApplication];
    [self.searchSpinner setHidden:true];
}

- (void)disableSearchButton {
    self.searching = YES;
    self.searchButton.enabled = false;
    [self.searchButton setTitle:@"" forState:UIControlStateDisabled];
    [self.searchSpinner setHidden:false];
    [self.searchSpinner startAnimating];
}

- (void)resetSearchViewFields {
    self.departureField.text = nil;
    self.arrivalField.text = nil;
    self.bikeField.text = @"1";
    self.standField.text = @"1";
    
    self.departureCLLocation = nil;
    self.departureStation = nil;
    self.arrivalCLLocation = nil;
    self.arrivalStation = nil;
}

- (void)openSearchPanel {
    [UIView animateWithDuration:0.5 animations:^{
        CGRect searchFrame = self.searchPanel.frame;
        searchFrame.origin.y = 0;
        self.searchPanel.frame = searchFrame;
    }];
    if (self.isLocationServiceEnabled != nil) {
        self.departureLocation.enabled = [self.isLocationServiceEnabled boolValue];
        self.arrivalLocation.enabled = [self.isLocationServiceEnabled boolValue];
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
    [self.departureAutocompleteView hide];
    [self.arrivalAutocompleteView hide];
}

- (void)searchWithDeparture:(CLLocation *)departure andArrival:(CLLocation *)arrival withBikes:(int)bikes andAvailableStands:(int)availableStands inARadiusOf:(int)radius {
    NSLog(@"%f,%f -> %f,%f (%d / %d)", departure.coordinate.latitude, departure.coordinate.longitude, arrival.coordinate.latitude, arrival.coordinate.longitude, bikes, availableStands);
    self.mapViewState = MAP_VIEW_SEARCH_STATE;
    [self refreshNavigationBarHasSearchView:_isSearchViewVisible hasRideView:self.mapViewState == MAP_VIEW_SEARCH_STATE];
    [self eraseAnnotations];
    [self eraseRoute];
    [self eraseSearchAnnotations];
    [self searchCloseStationsAroundDeparture:departure withBikesNumber:bikes andMaxStationsNumber:SEARCH_RESULT_MAX_STATIONS_NUMBER inARadiusOf:radius];
    [self searchCloseStationsAroundArrival:arrival withAvailableStandsNumber:availableStands andMaxStationsNumber:SEARCH_RESULT_MAX_STATIONS_NUMBER inARadiusOf:radius];
    if ([self.departureCloseStations count] > 0 && [self.arrivalCloseStations count] > 0 && self.departureStation != nil && self.arrivalStation != nil) {
        [self drawSearchAnnotations];
        [self drawRouteFromStationDeparture:self.departureStation toStationArrival:self.arrivalStation];
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
                    
                    if (![self.departureCloseStations containsObject:station] && [self unlessInMeters:radius from:location.coordinate for:stationCoordinate]) {
                        if ([station.availableBikes integerValue] >= bikesNumber) {
                            NSLog(@"close station found at %d m : %@ - %@ available bikes", radius, station.name, station.availableBikes);
                            [self.departureCloseStations addObject:station];
                            if (self.departureStation == nil) {
                                self.departureStation = station;
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
                    
                    if (![self.arrivalCloseStations containsObject:station] && [self unlessInMeters:radius from:location.coordinate for:stationCoordinate]) {
                        if ([station.availableBikeStands integerValue] >= availableStandsNumber) {
                            NSLog(@"close station found at %d m : %@ - %@ available stands", radius, station.name, station.availableBikeStands);
                            [self.arrivalCloseStations addObject:station];
                            if (self.arrivalStation == nil) {
                                self.arrivalStation = station;
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

-(void)setCurrentContract {
    BOOL invalidateCurrentContract = NO;
    if (self.currentContract != nil) {
        if (![GeoUtils isLocation:self.mapPanel.region.center inRegion:self.currentContract.region]) {
            invalidateCurrentContract = YES;
            self.currentContract = nil;
        }
    }
    if (self.currentContract == nil || invalidateCurrentContract) {
        for (Contract *aContract in self.allContracts) {
            if ([GeoUtils isLocation:self.mapPanel.region.center inRegion:aContract.region]) {
                self.currentContract = aContract;
                break;
            }
        }
    }
    if (self.currentContract != nil) {
        NSLog(@"current contract : %@ (%@)", self.currentContract.name, [Contract getProviderNameFromContractProvider:self.currentContract.provider]);
    } else {
        NSLog(@"out of contract cover");
    }
}

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

-(double) getStationDistanceBetween:(Station *)first and:(Station *)second {
    return [GeoUtils getDistanceFromLat:first.latitude.doubleValue toLat:second.latitude.doubleValue fromLong:first.longitude.doubleValue toLong:second.longitude.doubleValue];
}

-(double) getDistanceBetween:(Station *)aStation and:(ClusterAnnotation *)aCluster {
    return [GeoUtils getDistanceFromLat:aStation.latitude.doubleValue toLat:aCluster.coordinate.latitude fromLong:aStation.longitude.doubleValue toLong:aCluster.coordinate.longitude];
}

-(double) getClusterDistanceBetween:(ClusterAnnotation *)first and:(ClusterAnnotation *)second {
    return [GeoUtils getDistanceFromLat:first.coordinate.latitude toLat:second.coordinate.latitude fromLong:first.coordinate.longitude toLong:second.coordinate.longitude];
}

- (BOOL)unlessInMeters:(double)radius from:(CLLocationCoordinate2D)origin for:(CLLocationCoordinate2D)location {
    double dist = [GeoUtils getDistanceFromLat:origin.latitude toLat:location.latitude fromLong:origin.longitude toLong:location.longitude];
    return dist <= radius;
}

- (MKCoordinateRegion)generateRegionForSearchMode:(NSMutableArray*)annotations {
    
    MKMapRect mapRect = MKMapRectNull;
    MKMapPoint annotationPoint;
    MKMapRect pointRect;
    for (id<MKAnnotation> annotation in annotations) {
        
        annotationPoint = MKMapPointForCoordinate(annotation.coordinate);
        pointRect = MKMapRectMake(annotationPoint.x, annotationPoint.y, 0, 0);
        
        if (MKMapRectIsNull(mapRect)) {
            mapRect = pointRect;
        } else {
            mapRect = MKMapRectUnion(mapRect, pointRect);
        }
    }
    MKCoordinateRegion region = MKCoordinateRegionForMapRect(mapRect);
    // add a padding to map
    region.span.latitudeDelta  *= MAP_PADDING_FACTOR;
    region.span.longitudeDelta *= MAP_PADDING_FACTOR;
    return region;
}

- (MKCoordinateRegion)generateRegionForDefaultMode:(NSMutableArray*)someStations {
    
    MKMapRect mapRect = MKMapRectNull;
    MKMapPoint annotationPoint;
    MKMapRect pointRect;
    
    if (someStations != nil && someStations.count > 0) {
        for (Station *aStation in someStations) {
            
            annotationPoint = MKMapPointForCoordinate(aStation.coordinate);
            pointRect = MKMapRectMake(annotationPoint.x, annotationPoint.y, 0, 0);
            
            if (MKMapRectIsNull(mapRect)) {
                mapRect = pointRect;
            } else {
                mapRect = MKMapRectUnion(mapRect, pointRect);
            }
        }
    }
    return MKCoordinateRegionForMapRect(mapRect);
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
