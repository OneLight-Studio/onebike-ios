//
//  MapController.h
//  velibnroses
//
//  Created by Thomas on 04/07/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import <MapKit/MapKit.h>

@interface MapController : UIViewController <MKMapViewDelegate,UITextFieldDelegate>

@property (weak,readwrite) IBOutlet MKMapView *mapPanel;
@property (weak,readwrite) IBOutlet UIView *searchPanel;
@property (weak,readwrite) IBOutlet UITextField *departureField;
@property (weak,readwrite) IBOutlet UITextField *arrivalField;
@property (weak,readwrite) IBOutlet UITextField *bikeField;
@property (weak,readwrite) IBOutlet UITextField *standField;
@property (weak,readwrite) IBOutlet UIButton *closeSearchPanelButton;
@property (weak,readwrite) IBOutlet UIBarButtonItem *infoBarButton;
@property (weak,readwrite) IBOutlet UIButton *searchButton;
@property (weak,readwrite) IBOutlet UIButton *departureLocation;
@property (weak,readwrite) IBOutlet UIActivityIndicatorView *departureSpinner;
@property (weak,readwrite) IBOutlet UIButton *arrivalLocation;
@property (weak,readwrite) IBOutlet UIActivityIndicatorView *arrivalSpinner;
@property (weak,readwrite) IBOutlet UIActivityIndicatorView *searchSpinner;
@property (weak,readwrite) IBOutlet UIView *infoPanel;
@property (weak,readwrite) IBOutlet UITextField *infoDistanceTextField;
@property (weak,readwrite) IBOutlet UITextField *infoDurationTextField;

@property (strong,readwrite) IBOutlet UIBarButtonItem *searchBarButton;
@property (strong,readwrite) IBOutlet UIBarButtonItem *cancelBarButton;

- (IBAction)searchBarButtonClicked:(id)sender;
- (IBAction)userLocationAsDepartureClicked:(id)sender;
- (IBAction)userLocationAsArrivalClicked:(id)sender;
- (IBAction)searchButtonClicked:(id)sender;
- (IBAction)cancelBarButtonClicked:(id)sender;
- (IBAction)bikeIconClicked:(id)sender;
- (IBAction)standIconClicked:(id)sender;

@end
