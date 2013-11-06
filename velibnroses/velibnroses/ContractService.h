//
//  ContractService.h
//  OneBike
//
//  Created by Sébastien BALARD on 27/10/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import "Contract.h"

@interface ContractService : NSObject

@property (strong,readonly) NSMutableArray *allContracts;

- (NSUInteger)loadContracts;
- (void)loadStationsFromContract:(Contract *)aContract success:(void(^)(NSMutableArray *))successBlock failure:(void(^)(NSError *))failureBlock timeout:(void(^)(void))timeoutBlock;
- (Contract *)getContractFromCoordinate:(CLLocationCoordinate2D)aCoordinate;

@end
