//
//  MapController.h
//  velibnroses
//
//  Created by Thomas on 04/07/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>
#import "CoreLocationHelper.h"

@interface MapController : UIViewController <CoreLocationHelperDelegate, UITextFieldDelegate> {
    @private CLLocationCoordinate2D currentLocation;
}

@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UIView *searchView;
@property (weak, nonatomic) IBOutlet UITextField *departureField;
@property (weak, nonatomic) IBOutlet UITextField *arrivalField;
@property (weak, nonatomic) IBOutlet UITextField *bikeField;
@property (weak, nonatomic) IBOutlet UIStepper *bikeStepper;
@property (nonatomic, retain) CoreLocationHelper *locationHelper;

- (IBAction)bikesChanged:(UIStepper *)stepper;
- (IBAction)toggleSearchView:(id)sender;
- (IBAction)useMyLocationAsDeparture:(id)sender;
- (IBAction)useMyLocationAsArrival:(id)sender;
- (IBAction)search:(id)sender;

@end
