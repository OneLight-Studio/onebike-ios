//
//  PlaceService.h
//  OneBike
//
//  Created by Sébastien BALARD on 28/10/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import "Place.h"

@interface PlaceService : NSObject

- (BOOL)areInTheSameContractsDeparture:(Place *)aDeparture AndArrival:(Place *)anArrival;
- (double)getDistanceBetweenDeparture:(Place *)aDeparture andArrival:(Place *)anArrival betweenMinRadius:(double)minRadius andMaxRadius:(double)maxRadius;
- (BOOL)isSamePlaceBetween:(Place *)first and:(Place *)second;

@end
