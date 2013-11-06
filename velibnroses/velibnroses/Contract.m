//
//  Contract.m
//  OneBike
//
//  Created by Sébastien BALARD on 17/10/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import "Contract.h"

@implementation Contract

+ (Contract *)fromJSON:(id)json {
    if (json == (id)[NSNull null]) {
        return nil;
    }
    
    Contract *contract = [[Contract alloc] init];
    contract.name = [json valueForKey:@"name"];
    contract.latitude = [NSNumber numberWithDouble:[[json valueForKey:@"lat"] doubleValue]];
    contract.longitude = [NSNumber numberWithDouble:[[json valueForKey:@"lng"] doubleValue]];
    switch ([Contract getContractProviderFromProviderName:[json valueForKey:@"provider"]]) {
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

+ (NSString *)getProviderNameFromContractProvider:(ContractProvider)provider {
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

+ (ContractProvider)getContractProviderFromProviderName:(NSString *)name {
    ContractProvider result = kUnknownProvider;
    if ([name isEqualToString:@"JCDecaux"]) {
        result = kJCDecaux;
    } else if ([name isEqualToString:@"CityBikes"]) {
        result = kCityBikes;
    }
    return result;
}

- (CLLocationCoordinate2D)center {
    CLLocationCoordinate2D cc2d;
    cc2d.latitude = self.latitude.doubleValue;
    cc2d.longitude = self.longitude.doubleValue;
    return cc2d;
}

- (MKCoordinateRegion)region {
    return MKCoordinateRegionMakeWithDistance(self.center, self.radius.doubleValue * 2, self.radius.doubleValue * 2);
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
    if (self.latitude == nil) {
        if (other.latitude != nil) {
            return false;
        }
    } else if (self.longitude == nil) {
        if (other.longitude != nil) {
            return false;
        }
    } else if (![self.latitude isEqual:other.latitude]) {
        return false;
    } else if (![self.longitude isEqual:other.longitude]) {
        return false;
    } else if (self.provider != other.provider) {
        return false;
    }
    return true;
}

- (NSUInteger)hash {
    const NSUInteger prime = 31;
    NSUInteger result = 1;
    result = prime * result + [self.latitude hash];
    result = prime * result + [self.longitude hash];
    result = prime * result + self.provider;
    return result;
}
@end
