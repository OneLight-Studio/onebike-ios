//
//  Contract.h
//  OneBike
//
//  Created by Sébastien BALARD on 17/10/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import <MapKit/MapKit.h>

typedef enum
{
    kUnknownProvider, kJCDecaux, kCityBikes
} ContractProvider;

@interface Contract : NSObject <NSCopying>

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSNumber *latitude;
@property (nonatomic, strong) NSNumber *longitude;
@property (nonatomic, assign) ContractProvider provider;
@property (nonatomic, strong) NSNumber *radius;
@property (nonatomic, strong) NSString *url;
@property (nonatomic, readonly) CLLocationCoordinate2D center;
@property (nonatomic, readonly) MKCoordinateRegion region;

+ (Contract *)fromJSON:(id)json;
+ (NSArray *)fromJSONArray:(id)json;
+ (NSString *)getProviderNameFromContractProvider:(ContractProvider)provider;
+ (ContractProvider)getContractProviderFromProviderName:(NSString *)name;

@end
