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
#define STATION_SEARCH_RADIUS_IN_METERS 50
#define STATION_SEARCH_MIN_RADIUS_IN_METERS 500
#define STATION_SEARCH_MAX_RADIUS_IN_METERS 5000
#define MERCATOR_RADIUS 85445659.44705395
#define MAX_ZOOM_LEVEL 20
#define MAP_PADDING_FACTOR 1.25
#define INVALID_STATIONS @[@"TEST EDOS"]

// web services

#define WS_REQUEST_TIMEOUT 10
#define TIME_BEFORE_REFRESH_DATA_IN_SECONDS 30

#define JCD_TIMED_OUT_REQUEST_EXCEPTION_CODE -1001
#define JCD_WS_ENTRY_POINT_PARAM_VALUE @"https://api.jcdecaux.com/vls/v1/stations"
#define JCD_API_KEY_PARAM_NAME @"apiKey"
#define JCD_CONTRACT_KEY_PARAM_NAME @"contract"

#define GOOGLE_MAPS_WS_ENTRY_POINT_PARAM_VALUE @"https://maps.googleapis.com/maps/api/directions/json"
#define GOOGLE_MAPS_API_ORIGIN_PARAM_NAME @"origin"
#define GOOGLE_MAPS_API_DESTINATION_PARAM_NAME @"destination"
#define GOOGLE_MAPS_API_LANGUAGE_PARAM_NAME @"language"
#define GOOGLE_MAPS_API_MODE_PARAM_NAME @"mode"
#define GOOGLE_MAPS_API_SENSOR_PARAM_NAME @"sensor"

// notification

#define NOTIFICATION_DID_ENTER_BACKGROUND @"applicationDidEnterBackground"
#define NOTIFICATION_WILL_ENTER_FOREGROUND @"applicationWillEnterForeground"

// misc
#define MAP_VIEW_DEFAULT_STATE 0
#define MAP_VIEW_SEARCH_STATE 1
#define SEARCH_RESULT_MAX_STATIONS_NUMBER 3

// email
#define EMAIL_RECIPIENT @"support@onelight-studio.com"
