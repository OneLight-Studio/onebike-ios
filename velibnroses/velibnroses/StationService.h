//
//  StationService.h
//  OneBike
//
//  Created by Sébastien BALARD on 28/10/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import "Place.h"

@interface StationService : NSObject

- (NSMutableArray *)searchCloseStationsIn:(NSMutableArray *)contractStations forPlace:(Place *)aPlace withBikesNumber:(int)bikesNumber andMaxStationsNumber:(int)maxStationsNumber inARadiusOf:(int)maxRadius;

@end
