//
//  ContractAnnotation.h
//  OneBike
//
//  Created by Sébastien BALARD on 18/10/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import <MapKit/MapKit.h>

@interface ContractAnnotation : MKPointAnnotation

@property (nonatomic, assign) MKCoordinateRegion region;

@end
