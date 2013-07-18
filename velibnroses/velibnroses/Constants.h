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
#define MIN_DIST_INTERVAL_IN_METER 50
#define ZOOM_SQUARE_SIDE_IN_KM 0.5*METERS_PER_MILE
#define EARTH_RADIUS_IN_METERS 6371000

// WS

#define JCD_WS_ENTRY_POINT_PARAM_VALUE @"https://api.jcdecaux.com/vls/v1/stations"
#define JCD_API_KEY_PARAM_NAME @"apiKey"
#define JCD_API_KEY_PARAM_VALUE @"e774968643aee3788d9b83be4651ba671aba7611"
#define JCD_CONTRACT_KEY_PARAM_NAME @"contract"