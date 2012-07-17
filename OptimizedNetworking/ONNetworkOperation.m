//
//  ONNetworkOperation.m
//  OptimizedNetworking
//
//  Created by Brennan Stehling on 7/10/12.
//  Copyright (c) 2012 SmallSharpTools LLC. All rights reserved.
//

#import "ONNetworkOperation.h"

#import "ONNetworkManager.h"
#import "ONDownloadItem.h"

@interface ONNetworkOperation () <NSURLConnectionDataDelegate>

@property (strong, nonatomic) NSMutableData *receivedData;
@property (strong, nonatomic) NSDate *operationStartDate;
@property (strong, nonatomic) NSDate *operationEndDate;

- (void)startNetworkOperation;
- (void)cancelNetworkOperation;
- (void)failNetworkOperation;
- (void)finishNetworkOperation;

- (BOOL)isCompleted;

- (NSString *)statusAsString;

@end

@implementation ONNetworkOperation

@synthesize completionHandler = _completionHandler;

@synthesize connection = _connection;
@synthesize receivedData = _receivedData;
@synthesize operationStartDate = _operationStartDate;
@synthesize operationEndDate = _operationEndDate;

@synthesize url =_url;
@synthesize category = _category;
@synthesize status = _status;
@synthesize error = _error;

#pragma mark - Public Methods
#pragma mark -

- (void)changeStatus:(ONNetworkOperation_Status)status {
    if (self.status != ONNetworkOperation_Status_Ready && status == ONNetworkOperation_Status_Ready) {
        [self willChangeValueForKey:@"isReady"];
        self.status = ONNetworkOperation_Status_Ready;
        [self didChangeValueForKey:@"isReady"];
    }
    else if (self.status != ONNetworkOperation_Status_Executing && status == ONNetworkOperation_Status_Executing) {
        [self willChangeValueForKey:@"isExecuting"];
        self.status = ONNetworkOperation_Status_Executing;
        [self didChangeValueForKey:@"isExecuting"];
    }
    else if (self.status != ONNetworkOperation_Status_Cancelled && status == ONNetworkOperation_Status_Cancelled) {
        [self willChangeValueForKey:@"isCancelled"];
        self.status = ONNetworkOperation_Status_Cancelled;
        [self didChangeValueForKey:@"isCancelled"];
    }
    else if (self.status != ONNetworkOperation_Status_Finished && status == ONNetworkOperation_Status_Finished) {
        [self willChangeValueForKey:@"isFinished"];
        self.status = ONNetworkOperation_Status_Finished;
        [self didChangeValueForKey:@"isFinished"];
    }
}

- (NSTimeInterval)operationDuration {
    if (self.error != nil || self.operationStartDate == nil || self.operationEndDate == nil) {
        return 0.0;
    }
    
    CGFloat duration = [self.operationEndDate timeIntervalSinceDate:self.operationStartDate];
    DebugLog(@"duration: %f", duration);
    return duration;
}

#pragma mark - Private Methods
#pragma mark -

- (NSString *)statusAsString {
    if (self.status = ONNetworkOperation_Status_Waiting) {
        return @"Waiting";
    }
    else if (self.status = ONNetworkOperation_Status_Ready) {
        return @"Ready";
    }
    else if (self.status = ONNetworkOperation_Status_Executing) {
        return @"Executing";
    }
    else if (self.status = ONNetworkOperation_Status_Cancelled) {
        return @"Cancelled";
    }
    else if (self.status = ONNetworkOperation_Status_Finished) {
        return @"Finished";
    }
    else {
        return @"Unknown";
    }
}

#pragma mark - NSObject Overrides
#pragma mark -

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ (%@, %@)", self.url.absoluteString, self.category, [self statusAsString]];
}

#pragma mark - Base Class Overrides
#pragma mark -

- (void)startNetworkOperation {
    // meant to be overridden
    
    // NOTE: Networking on the networking queue should not be happening on the main queue
    assert(dispatch_get_main_queue() != dispatch_get_current_queue());
    
    if (dispatch_get_main_queue() != dispatch_get_current_queue()) {
        DebugLog(@"Starting URL connection on secondary queue");
    }
    
    // use the default cache policy to do the memory/disk caching
    NSMutableURLRequest *request = [NSMutableURLRequest 
                                    requestWithURL:self.url 
                                    cachePolicy:NSURLRequestUseProtocolCachePolicy 
                                    timeoutInterval:30];
    
    // ensure a fresh response is returned
    [request setValue:@"Cache-Control" forHTTPHeaderField:@"no-cache"];
    
    self.connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    [self.connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.connection start];
    
    if (self.connection == nil) {
        /* inform the user that the connection failed */
        
        NSString *errorMessage = [NSString stringWithFormat:@"Error creating connection (%@)", self.url];
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:errorMessage forKey:NSLocalizedDescriptionKey];
        NSError *error = [NSError errorWithDomain:@"ONNetworkOperationErrorDomain"
                                             code:100
                                         userInfo:userInfo];
        DebugLog(@"Error: %@", errorMessage);
        self.completionHandler(nil, error);
        [self changeStatus:ONNetworkOperation_Status_Finished];
        return;
    }
    
    [[ONNetworkManager sharedInstance] didStartNetworking];
}

- (void)cancelNetworkOperation {
    @synchronized (self) {
        self.operationEndDate = [NSDate date];
        [self.connection cancel];
        [[ONNetworkManager sharedInstance] didStopNetworking];
        [self changeStatus:ONNetworkOperation_Status_Cancelled];
    }
}

- (void)failNetworkOperation {
    @synchronized (self) {
        self.operationEndDate = [NSDate date];
        [[ONNetworkManager sharedInstance] didStopNetworking];
        [self changeStatus:ONNetworkOperation_Status_Finished];
        self.completionHandler(nil, self.error);
    }
}

- (void)finishNetworkOperation {
    @synchronized (self) {
        self.operationEndDate = [NSDate date];
        [[ONNetworkManager sharedInstance] didStopNetworking];
        [self changeStatus:ONNetworkOperation_Status_Finished];
        self.completionHandler(self.receivedData, nil);
    }
}

- (BOOL)isCompleted {
    return [self isCancelled] || [self isFinished];
}

#pragma mark - NSOperation Overrides
#pragma mark -

- (void)start {
    DebugLog(@"starting network operation");
    [super start];
    
    assert(![self isCompleted]);

    self.operationStartDate = [NSDate date];
    [self changeStatus:ONNetworkOperation_Status_Executing];
    [self startNetworkOperation];
    
    // run the run loop to allow delegate callbacks to run (moved to a thread in the manager) (See MVC Networking)
    do {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    } while ( ! [self isCompleted] );
}

- (void)cancel {    
    // any thread
    
    @synchronized (self) {
        // Call our super class so that isCancelled starts returning true immediately.
        [super cancel];
        [self cancelNetworkOperation];
        [self changeStatus:ONNetworkOperation_Status_Cancelled];
    }
}

- (BOOL)isReady {
    // any thread
    return self.status == ONNetworkOperation_Status_Ready;
}

- (BOOL)isConcurrent {
    // any thread
    return YES;
}

- (BOOL)isExecuting {
    // any thread
    return self.status == ONNetworkOperation_Status_Executing;
}

- (BOOL)isCancelled {
    // any thread
    return self.status == ONNetworkOperation_Status_Cancelled;
}

- (BOOL)isFinished {
    // any thread
    return self.status == ONNetworkOperation_Status_Finished;
}

#pragma mark - NSURLConnectionDataDelegate
#pragma mark -

- (void)connection:(NSURLConnection *)theConnection didReceiveResponse:(NSURLResponse *)response {
	/* create the NSMutableData instance that will hold the received data */
    
    if([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode != 200) {
            
            NSString *errorMessage = [NSString stringWithFormat:@"Error during network operation: %i", httpResponse.statusCode];
            NSDictionary *userInfo = [NSDictionary dictionaryWithObject:errorMessage forKey:NSLocalizedDescriptionKey];
            NSError *error = [NSError errorWithDomain:@"ONNetworkOperationErrorDomain"
                                                 code:httpResponse.statusCode
                                             userInfo:userInfo];
            self.completionHandler(nil, error);
            [self cancelNetworkOperation];
            return;
        }
    }
    
	long long contentLength = [response expectedContentLength];
	if (contentLength == NSURLResponseUnknownLength) {
		contentLength = 500000;
	}
	self.receivedData = [NSMutableData dataWithCapacity:(NSUInteger)contentLength];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)data {
    /* Append the new data to the received data. */
//    DebugLog(@"didReceiveData: %@", self);
    [self.receivedData appendData:data];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error {
//    DebugLog(@"didFailWithError: %@", error);
    self.error = error;
    [self failNetworkOperation];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection {
//    DebugLog(@"connectionDidFinishLoading");
    [self finishNetworkOperation];
}

@end
