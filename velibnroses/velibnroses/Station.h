//
//  Station.h
//  Velib N' Roses
//
//  Created by Sébastien BALARD on 16/07/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import <MapKit/MapKit.h>
#import "Contract.h"

typedef enum
{
    kOpen, kClosed
} StationState;

@interface Station : NSObject <NSCopying>

@property (strong,readwrite) NSString *name;
@property (strong,readwrite) NSString *address;
@property (strong,readwrite) NSNumber *latitude;
@property (strong,readwrite) NSNumber *longitude;
@property (strong,readwrite) NSNumber *bikeStands;
@property (strong,readwrite) NSNumber *availableBikeStands;
@property (strong,readwrite) NSNumber *availableBikes;
@property (assign,readwrite) BOOL banking;
@property (assign,readwrite) StationState status;
@property (assign,readonly) CLLocationCoordinate2D coordinate;

+ (Station *)parseJSONObject:(id)json fromProvider:(ContractProvider)provider;
+ (NSArray *)parseJSONArray:(id)json fromProvider:(ContractProvider)provider;

@end
