//
//  ClusterAnnotation.h
//  OneBike
//
//  Created by Sébastien BALARD on 16/09/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import <MapKit/MapKit.h>

@interface ClusterAnnotation : MKPointAnnotation

@property (nonatomic, assign) MKCoordinateRegion region;

@end
