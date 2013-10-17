//
//  Contract.m
//  OneBike
//
//  Created by Sébastien BALARD on 17/10/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import "Contract.h"

@implementation Contract

@synthesize name, latitude, longitude, provider, radius, url;

+ (Contract *)fromJSON:(id)json {
    if (json == (id)[NSNull null]) {
        return nil;
    }
    
    Contract *contract = [[Contract alloc] init];
    contract.name = [json valueForKey:@"name"];
    contract.latitude = [NSNumber numberWithDouble:[[json valueForKey:@"lat"] doubleValue]];
    contract.longitude = [NSNumber numberWithDouble:[[json valueForKey:@"lng"] doubleValue]];
    switch ([Contract getContractProviderForName:[json valueForKey:@"provider"]]) {
        case kJCDecaux:
            contract.provider = kJCDecaux;
            break;
        case kCityBikes:
            contract.provider = kCityBikes;
            break;
        default:
            contract.provider = kUnknownProvider;
            break;
    }
    contract.radius = [NSNumber numberWithDouble:[[json valueForKey:@"radius"] doubleValue]];
    contract.url = [json valueForKey:@"url"];
    
    return contract;
}

+ (NSArray *)fromJSONArray:(id)json {
    NSMutableArray *array = [NSMutableArray array];
    for (id jsonObject in json) {
        Contract *contract = [self fromJSON:jsonObject];
        if (contract != nil) {
            [array addObject:contract];
        }
    }
    return array;
}

+ (NSString *)getNameForContractProvider:(ContractProvider)provider {
    NSString *result = nil;
    switch (provider) {
        case kJCDecaux:
            result = @"JCDecaux";
            break;
        case kCityBikes:
            result = @"CityBikes";
            break;
        default:
            result = @"";
            break;
    }
    return result;
}

+ (ContractProvider)getContractProviderForName:(NSString *)name {
    ContractProvider result = kUnknownProvider;
    if ([name isEqualToString:@"JCDecaux"]) {
        result = kJCDecaux;
    } else if ([name isEqualToString:@"CityBikes"]) {
        result = kCityBikes;
    }
    return result;
}

- (CLLocationCoordinate2D) coordinate {
    CLLocationCoordinate2D cc2d;
    cc2d.latitude = latitude.doubleValue;
    cc2d.longitude = longitude.doubleValue;
    return cc2d;
}

- (id)copyWithZone:(NSZone *)zone
{
    id copy = [[[self class] alloc] init];
    if (copy) {
        // Set primitives
        [copy setProvider:self.provider];
        
        // Copy NSObject subclasses
        [copy setName:[self.name copyWithZone:zone]];
        [copy setLatitude:[self.latitude copyWithZone:zone]];
        [copy setLongitude:[self.longitude copyWithZone:zone]];
        [copy setRadius:[self.radius copyWithZone:zone]];
        [copy setUrl:[self.url copyWithZone:zone]];
    }
    
    return copy;
}

- (BOOL)isEqual:(id)object {
    if (self == object)
        return true;
    if ([self class] != [object class])
        return false;
    Contract *other = (Contract *)object;
    if (latitude == nil) {
        if (other.latitude != nil) {
            return false;
        }
    } else if (longitude == nil) {
        if (other.longitude != nil) {
            return false;
        }
    } else if (![latitude isEqual:other.latitude]) {
        return false;
    } else if (![longitude isEqual:other.longitude]) {
        return false;
    } else if (provider != other.provider) {
        return false;
    }
    return true;
}

- (NSUInteger)hash {
    const NSUInteger prime = 31;
    NSUInteger result = 1;
    result = prime * result + [latitude hash];
    result = prime * result + [longitude hash];
    result = prime * result + provider;
    return result;
}
@end
