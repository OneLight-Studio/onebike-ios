//
//  CoreLocationHelper.h
//  Velib N' Roses
//
//  Created by Sébastien BALARD on 12/07/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@protocol CoreLocationHelperDelegate
@required
- (void)updateLocation:(CLLocation *)location;
- (void)locationError:(NSError *)error;
@end

@interface CoreLocationHelper : NSObject <CLLocationManagerDelegate>

@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) id<CoreLocationHelperDelegate> delegate;

@end
