//
//  Place.h
//  OneBike
//
//  Created by Sébastien BALARD on 25/10/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "Contract.h"

@interface Place : NSObject

@property (strong,readwrite) CLLocation *location;
@property (strong,readwrite) Contract *contract;

@end
