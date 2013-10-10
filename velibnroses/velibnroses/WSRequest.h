//
//  WSRequest.h
//  VelibNRoses
//
//  Created by Thomas on 07/08/12.
//  Copyright (c) 2012 OneLight. All rights reserved.
//

typedef void(^WSErrorHandler)(int);
typedef void(^WSExceptionHandler)(NSError *);
typedef void(^WSResultHandler)(id);
typedef void(^WSFunction)();

@interface WSRequest : NSObject <NSURLConnectionDelegate>

- (id)initWithResource:(NSString *)resource inBackground:(BOOL)background;
- (WSRequest *)appendParameterWithKey:(NSString *)key andValue:(id)value;
- (WSRequest *)doAfter:(WSFunction)function;
- (WSRequest *)doBefore:(WSFunction)function;
- (WSRequest *)handleErrorWith:(WSErrorHandler)handler;
- (WSRequest *)handleExceptionWith:(WSExceptionHandler)handler;
- (WSRequest *)handleResultWith:(WSResultHandler)handler;
- (void)call;
- (void)defaultAfterFunction;
- (void)defaultBeforeFunction;
- (void)defaultErrorHandler:(int)errorCode;
- (void)defaultExceptionHandler:(NSError *)exception;
- (void)defaultResultHandler:(id)json;
- (void)doBefore;
- (void)doAfter;
- (void)onError:(int)errorCode;
- (void)onException:(NSError *)exception;
- (void)onResult:(id)json;

@end
