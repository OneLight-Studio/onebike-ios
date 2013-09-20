//
//  Station.h
//  Velib N' Roses
//
//  Created by Sébastien BALARD on 16/07/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import <MapKit/MapKit.h>

typedef enum
{
    kOpen, kClosed
} StationState;

@interface Station : NSObject <NSCopying>

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *address;
@property (nonatomic, strong) NSString *contract;
@property (nonatomic, strong) NSNumber *latitude;
@property (nonatomic, strong) NSNumber *longitude;
@property (nonatomic, assign) BOOL banking;
@property (nonatomic, assign) StationState status;
@property (nonatomic, strong) NSNumber *bikeStands;
@property (nonatomic, strong) NSNumber *availableBikeStands;
@property (nonatomic, strong) NSNumber *availableBikes;
@property (nonatomic, readonly) CLLocationCoordinate2D coordinate;

+ (Station *)fromJSON:(id)json;
+ (NSArray *)fromJSONArray:(id)json;

@end
