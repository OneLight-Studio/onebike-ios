//
//  WSRequest.m
//  VelibNRoses
//
//  Created by Thomas on 07/08/12.
//  Copyright (c) 2012 OneLight. All rights reserved.
//

#import "SBJson.h"
#import "WSRequest.h"

@implementation WSRequest {
    NSString *_resource;
    NSMutableDictionary *_params;
    WSFunction _afterFunction;
    WSFunction _beforeFunction;
    WSErrorHandler _errorHandler;
    WSExceptionHandler _exceptionHandler;
    WSResultHandler _resultHandler;
    NSMutableData *_data;
    NSUInteger _httpCode;
    NSString *_mimeType;
    BOOL _background;
}

- (id)init {
    [NSException raise:@"Forbidden call to init" format:@"You must init a WSRequest by calling initWithResource method."];
    return nil;
}

- (id)initWithResource:(NSString *)aResource inBackground:(BOOL)inBackground {
    if (self = [super init]) {
        _resource = [aResource stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        _params = [[NSMutableDictionary alloc] init];
        _data = [[NSMutableData alloc] init];
        _background = inBackground;
    }
    return self;
}

- (WSRequest *)appendParameterWithKey:(NSString *)key andValue:(id)value {
    [NSException raise:@"Forbidden call to abstract method" format:@"appendParameterWithKey must be invoked from a subclass of WSRequest."];
    return self;
}

- (WSRequest *)doAfter:(WSFunction)function {
    _afterFunction = function;
    return self;
}

- (WSRequest *)doBefore:(WSFunction)function {
    _beforeFunction = function;
    return self;
}

- (WSRequest *)handleErrorWith:(WSErrorHandler)handler {
    _errorHandler = handler;
    return self;
}

- (WSRequest *)handleExceptionWith:(WSExceptionHandler)handler {
    _exceptionHandler = handler;
    return self;
}

- (WSRequest *)handleResultWith:(WSResultHandler)handler {
    _resultHandler = handler;
    return self;
}

- (void)call {
    NSMutableString *uri = [NSMutableString stringWithString:_resource];
    // append parameters
    if (_params.count > 0) {
        [uri appendString:@"?"];
    }
    for (id param in _params) {
        NSString *value = [_params objectForKey:param];
        [uri appendFormat:@"%@=%@&", param, [value stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    }
    // remove the last "&"
    if (uri.length > 0 && [uri hasSuffix:@"&"]) {
        [uri deleteCharactersInRange:NSMakeRange(uri.length - 1, 1)];
    }
    NSURL *url = [NSURL URLWithString:uri];
    // build the request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:timeout];
    [request setHTTPMethod:@"GET"];
    
    NSLog(@"Request %@ %@", request.HTTPMethod, request.URL.absoluteString);
    
    [self doBefore];
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    if (!connection) {
        [self doAfter];
        [self onException:nil];
    }
}

- (void) defaultAfterFunction {
    if (!_background) {
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    }
}

- (void) defaultBeforeFunction {
    if (!_background) {
        [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    }
}

- (void) defaultErrorHandler:(int)errorCode {
    NSLog(@"HTTP error %d", errorCode);
    if (!_background) {
        [[[UIAlertView alloc] initWithTitle:nil message:@"error" delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil] show];
    }
}

- (void) defaultExceptionHandler:(NSError *)exception {
    NSLog(@"Exception %@", exception.debugDescription);
    if (!_background) {
        [[[UIAlertView alloc] initWithTitle:nil message:exception.localizedDescription delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil] show];
    }
}

- (void) defaultResultHandler:(id)json {
}

- (void) doAfter {
    if (_afterFunction != nil) {
        _afterFunction();
    } else {
        [self defaultAfterFunction];
    }
}

- (void) doBefore {
    if (_beforeFunction != nil) {
        _beforeFunction();
    } else {
        [self defaultBeforeFunction];
    }
}

- (void) onError:(int)errorCode {
    if (_errorHandler != nil) {
        _errorHandler(errorCode);
    } else {
        [self defaultErrorHandler:errorCode];
    }
}

- (void) onException:(NSError *)exception {
    if (_exceptionHandler != nil) {
        _exceptionHandler(exception);
    } else {
        [self defaultExceptionHandler:exception];
    }
}

- (void) onResult:(id)json {
    if (_resultHandler != nil) {
        _resultHandler(json);
    } else {
        [self defaultResultHandler:json];
    }
}

- (void) connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self doAfter];
    [self onException:error];
}

- (void) connection:(NSURLConnection *)connection didReceiveData:(NSData *)someData {
    [_data appendData:someData];
}

- (void) connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    [_data setLength:0];
    _mimeType = response.MIMEType;
    _httpCode = [((NSHTTPURLResponse *)response) statusCode];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [self doAfter];
    NSLog(@"HTTP response %d", _httpCode);
    if (_httpCode >= 300) {
        [self onError:_httpCode];
    } else {
        if ([_mimeType isEqualToString:@"application/json"] || [_mimeType isEqualToString:@"text/plain"]) {
            NSString *jsonString = [[NSString alloc] initWithData:_data encoding:NSUTF8StringEncoding];
            if (jsonString.length > 0) {
                NSLog(@"JSON result %@", jsonString);
                [self onResult:[jsonString JSONValue]];
            } else {
                NSLog(@"No JSON result");
                [self onResult:nil];
            }
        }
    }
}

@end
