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
    kUnknownProvider,kJCDecaux,kCityBikes
} ContractProvider;

@interface Contract : NSObject <NSCopying>

@property (strong,readwrite) NSString *name;
@property (strong,readwrite) NSNumber *latitude;
@property (strong,readwrite) NSNumber *longitude;
@property (assign,readwrite) ContractProvider provider;
@property (strong,readwrite) NSNumber *radius;
@property (strong,readwrite) NSString *url;
@property (assign,readonly) CLLocationCoordinate2D center;
@property (assign,readonly) MKCoordinateRegion region;

+ (Contract *)fromJSON:(id)json;
+ (NSArray *)fromJSONArray:(id)json;
+ (NSString *)getProviderNameFromContractProvider:(ContractProvider)provider;
+ (ContractProvider)getContractProviderFromProviderName:(NSString *)name;

@end
