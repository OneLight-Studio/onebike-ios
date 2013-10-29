//
//  ContractService.m
//  OneBike
//
//  Created by Sébastien BALARD on 27/10/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import "ContractService.h"
#import "AFNetworking.h"
#import "Constants.h"
#import "Keys.h"
#import "Station.h"
#import "GeoUtils.h"

@interface ContractService ()

@property (strong,readwrite) NSMutableArray *allContracts;
@property (assign,readwrite) int requestAttemptsNumber;

@end

@implementation ContractService

- (id)init
{
    self = [super init];
    if (self) {
        self.requestAttemptsNumber = 0;
    }
    return self;
}

- (NSUInteger)loadContracts {
    NSError *error, *exception;
    NSUInteger count = 0;
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"contracts" ofType:@"json"];
    NSLog(@"load contracts from @%@", path);
    NSString *content = [[NSString alloc] initWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    if (error != nil) {
        NSLog(@"error occured during contracts json file loading  : %@", error.debugDescription);
    } else {
        id json = [NSJSONSerialization JSONObjectWithData:[content dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&exception];
        if (exception != nil) {
            NSLog(@"exception occured during json contracts data processing  : %@", exception.debugDescription);
        } else {
            self.allContracts = (NSMutableArray *)[Contract fromJSONArray:json];
            count = self.allContracts.count;
            NSLog(@"contracts found : %i", count);
        }
    }
    return count;
}

- (void)loadStationsFromContract:(Contract *)aContract success:(void(^)(NSMutableArray *))successBlock failure:(void(^)(NSError *))failureBlock timeout:(void(^)(void))timeoutBlock {
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    self.requestAttemptsNumber = 0;
    AFHTTPRequestOperation *request;
    switch (aContract.provider) {
        case kJCDecaux:
        {
            NSLog(@"call JCD ws for contract : %@", aContract.name);
            request = [manager GET:aContract.url parameters:@{JCD_API_KEY_PARAM_NAME:KEY_JCD} success:^(AFHTTPRequestOperation *operation, id responseObject) {
                NSLog(@"JCD ws result");
                NSMutableArray *contractStations = (NSMutableArray *)[Station parseJSONArray:responseObject fromProvider:kJCDecaux];
                NSLog(@"%@ has %i stations", aContract.name, contractStations.count);
                successBlock(contractStations);
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                if (error.code == JCD_TIMED_OUT_REQUEST_EXCEPTION_CODE) {
                    NSLog(@"jcd ws exception : expired request");
                    if (self.requestAttemptsNumber < 2) {
                        [operation start];
                        self.requestAttemptsNumber++;
                    } else {
                        timeoutBlock();
                    }
                } else {
                    failureBlock(error);
                }
            }];
            [request start];
            break;
        }
        case kCityBikes:
        {
            NSLog(@"call Citybikes ws for contract : %@", aContract.name);
            request = [manager GET:aContract.url parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
                NSLog(@"Citybikes ws result");
                NSMutableArray *contractStations = (NSMutableArray *)[Station parseJSONArray:responseObject fromProvider:kCityBikes];
                NSLog(@"%@ has %i stations", aContract.name, contractStations.count);
                successBlock(contractStations);
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                failureBlock(error);
            }];
            [request start];
            break;
        }
        default:
            break;
    }
}

- (Contract *)getContractFromCoordinate:(CLLocationCoordinate2D)aCoordinate {
    Contract *result = nil;
    for (Contract *aContract in self.allContracts) {
        if ([GeoUtils isLocation:aCoordinate inRegion:aContract.region]) {
            result = aContract;
            break;
        }
    }
    return result;
}

@end
