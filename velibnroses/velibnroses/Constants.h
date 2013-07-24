//
//  Constants.h
//  Velib N' Roses
//
//  Created by Sébastien BALARD on 16/07/13.
//  Copyright (c) 2013 OneLight Studio. All rights reserved.
//

// geolocalization

#define METERS_PER_MILE 1609.344
#define TLS_LAT 43.610477
#define TLS_LONG 1.443615
#define EARTH_RADIUS_IN_METERS 6371000
#define SPAN_SIDE_INIT_LENGTH_IN_METERS 500
#define SPAN_SIDE_MAX_LENGTH_IN_METERS 5000

// WS

#define TIME_BEFORE_REFRESH_DATA_IN_SECONDS 300
#define JCD_WS_ENTRY_POINT_PARAM_VALUE @"https://api.jcdecaux.com/vls/v1/stations"
#define JCD_API_KEY_PARAM_NAME @"apiKey"
#define JCD_API_KEY_PARAM_VALUE @"e774968643aee3788d9b83be4651ba671aba7611"
#define JCD_CONTRACT_KEY_PARAM_NAME @"contract"

// notification

#define NOTIFICATION_DID_ENTER_BACKGROUND @"applicationDidEnterBackground"
#define NOTIFICATION_WILL_ENTER_FOREGROUND @"applicationWillEnterForeground"

