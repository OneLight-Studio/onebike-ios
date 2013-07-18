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

@interface MapController : UIViewController <CoreLocationHelperDelegate>

@property (nonatomic, weak) IBOutlet MKMapView *mapView;
@property (nonatomic, retain) CoreLocationHelper *locationHelper;


@end
