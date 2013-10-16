//
//  MapController.h
//  velibnroses
//
//  Created by Thomas on 04/07/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import <MapKit/MapKit.h>

@interface MapController : UIViewController <MKMapViewDelegate, UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet MKMapView *mapPanel;
@property (weak, nonatomic) IBOutlet UIView *searchPanel;
@property (weak, nonatomic) IBOutlet UITextField *departureField;
@property (weak, nonatomic) IBOutlet UITextField *arrivalField;
@property (weak, nonatomic) IBOutlet UITextField *bikeField;
@property (weak, nonatomic) IBOutlet UITextField *standField;
@property (weak, nonatomic) IBOutlet UIButton *closeSearchPanelButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *searchBarButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *cancelBarButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *infoBarButton;
@property (weak, nonatomic) IBOutlet UIButton *searchButton;
@property (weak, nonatomic) IBOutlet UIButton *departureLocation;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *departureSpinner;
@property (weak, nonatomic) IBOutlet UIButton *arrivalLocation;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *arrivalSpinner;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *searchSpinner;
@property (weak, nonatomic) IBOutlet UIView *infoPanel;
@property (weak, nonatomic) IBOutlet UITextField *infoDistanceTextField;
@property (weak, nonatomic) IBOutlet UITextField *infoDurationTextField;

- (IBAction)searchBarButtonClicked:(id)sender;
- (IBAction)userLocationAsDepartureClicked:(id)sender;
- (IBAction)userLocationAsArrivalClicked:(id)sender;
- (IBAction)searchButtonClicked:(id)sender;
- (IBAction)cancelBarButtonClicked:(id)sender;
- (IBAction)bikeIconClicked:(id)sender;
- (IBAction)standIconClicked:(id)sender;

@end
