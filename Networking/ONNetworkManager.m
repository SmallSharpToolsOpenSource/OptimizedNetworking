//
//  ONNetworkManager.m
//  OptimizedNetworking
//
//  Created by Brennan Stehling on 7/10/12.
//  Copyright (c) 2012 SmallSharpTools LLC. All rights reserved.
//

#import "ONNetworkManager.h"

#import "ONDownloadItem.h"
#import "ONDownloadOperation.h"

// NOTES
// A download queue will regulate downloads. Download operations will be added to the queue
// and counted as they are in progress and new items will be added based on priority.
// A list of downloads will be downloaded at times and should be downloaded in the background
// with the ability for priority items to skip ahead of the line. Images will be handled
// differently than XML and other downloads because they take longer to download and will be
// stored using EGOCache.

// Look into AFNetworking - https://github.com/AFNetworking/AFNetworking

#pragma mark - Class Extension
#pragma mark -

@interface ONNetworkManager ()

@property (strong, readwrite, nonatomic) NSRecursiveLock *lock;
@property (strong, nonatomic) NSOperationQueue *networkQueue;
@property (strong, nonatomic) NSMutableArray *operations;
@property (assign, nonatomic) NSUInteger queuedCount;

@end

#pragma mark -

@implementation ONNetworkManager {
    NSUInteger networkingCount;
}

#pragma mark - Singleton
#pragma mark -

SYNTHESIZE_SINGLETON_FOR_CLASS(ONNetworkManager);

#pragma mark - Initialization
#pragma mark -

- (id)init {
    self = [super init];
    if (self != nil) {
        self.lock = [[NSRecursiveLock alloc] init];
        self.networkQueue = [[NSOperationQueue alloc] init];
        self.networkQueue.maxConcurrentOperationCount = NSOperationQueueDefaultMaxConcurrentOperationCount;
        self.operations = [NSMutableArray array];
        self.queuedCount = 0;
    }
    return self;
}

// This thread runs all of our network operation run loop callbacks.
+ (void) __attribute__((noreturn)) networkRunLoopThreadEntry:(id)__unused object {
    NSAssert(![NSThread isMainThread], @"Invalid State");
    do {
        @autoreleasepool {
            [[NSRunLoop currentRunLoop] run];
        }
    } while (YES);
    NSAssert(NO, @"Invalid State");
}

+ (NSThread *)networkRunLoopThread {
    static NSThread *_networkRunLoopThread = nil;
    static dispatch_once_t oncePredicate;
    
    dispatch_once(&oncePredicate, ^{
        _networkRunLoopThread = [[NSThread alloc] initWithTarget:self selector:@selector(networkRunLoopThreadEntry:) object:nil];
        // name thread for debugging
        [_networkRunLoopThread setName:@"networkRunLoopThread"];
        // lower priority
        if ( [_networkRunLoopThread respondsToSelector:@selector(setThreadPriority)] ) {
            [_networkRunLoopThread setThreadPriority:0.3];
        }
        [_networkRunLoopThread start];
    });
    
    return _networkRunLoopThread;
}

#pragma mark - Implementation
#pragma mark -

- (void)setMaxConcurrentOperationCount:(NSInteger)maxCount {
    self.networkQueue.maxConcurrentOperationCount = maxCount;
}

- (void)addOperations:(NSArray *)operations {
    [self.lock lock];
    NSArray *sorted = [ONNetworkManager sortOperations:operations];
    for (ONNetworkOperation *operation in sorted) {
        [self addOperation:operation];
    }
    [self.lock unlock];
}

- (void)addOperation:(ONNetworkOperation *)operation {
    [self.lock lock];
    
    // ensure the NSRunLoop thread is running
    NSAssert([[[self class] networkRunLoopThread] isExecuting], @"Invalid State");
    NSAssert(![[[self class] networkRunLoopThread] isFinished], @"Invalid State");
    NSAssert(![[[self class] networkRunLoopThread] isCancelled], @"Invalid State");
    
    [self.operations addObject:operation];
    
    __weak ONNetworkOperation *weakOperation = operation;
    
    [operation setCompletionBlock:^{
        [self.lock lock];
        self.queuedCount--;
        [self.operations removeObject:weakOperation];
        [self.lock unlock];
    }];
    
    NSAssert([operation respondsToSelector:@selector(setRunLoopThread:)], @"Invalid State");
    
    if ([operation respondsToSelector:@selector(setRunLoopThread:)]) {
        if ([(id)operation runLoopThread] == nil) {
            [(id)operation setRunLoopThread:[[self class] networkRunLoopThread]];
        }
    }
    
    [self.networkQueue addOperation:operation];
    [operation changeStatus:ONNetworkOperation_Status_Ready];
    self.queuedCount++;
    [self.lock unlock];
}

- (void)cancelOperation:(ONNetworkOperation *)operation {
    [self.lock lock];
    [operation cancel];
    [self.operations removeObjectIdenticalTo:operation];
    [self.lock unlock];
}

- (void)cancelOperationsWithCategory:(NSString *)category {
    [self.lock lock];
    NSMutableArray *operationsToCancel = [NSMutableArray array];
    for (ONNetworkOperation *operation in self.operations) {
        if ([operation.category isEqualToString:category]) {
            [operationsToCancel addObject:operation];
        }
    }
    
    for (ONNetworkOperation *operation in operationsToCancel) {
        [self cancelOperation:operation];
    }
    [self.lock unlock];
}

- (void)cancelAll {
    [self.lock lock];
    [self.networkQueue cancelAllOperations];
    [self.operations removeAllObjects];
    [self.lock unlock];
}

- (void)logOperations {
    [self.lock lock];
    DebugLog(@"There are %i active operations", [self operationsCount]);
    for (ONNetworkOperation *operation in self.operations) {
        DebugLog(@"%@", operation);
    }
    [self.lock unlock];
}

+ (NSArray *)sortOperations:(NSArray *)operations {
    // sort by status (waiting, queued, finished), priority, category
    NSArray *sorted = [operations sortedArrayUsingComparator: ^(id obj1, id obj2) {
        if ([obj1 isKindOfClass:[ONNetworkOperation class]] && [obj2 isKindOfClass:[ONNetworkOperation class]]) {
            ONNetworkOperation *op1 = (ONNetworkOperation *)obj1;
            ONNetworkOperation *op2 = (ONNetworkOperation *)obj2;
            
            NSComparisonResult result = (NSComparisonResult)NSOrderedSame;
            
            result = [[NSNumber numberWithInt:op1.status] compare:[NSNumber numberWithInt:op2.status]];
            
            if (result != NSOrderedSame) {
                if ([obj1 isKindOfClass:[ONDownloadOperation class]] && 
                    [obj2 isKindOfClass:[ONDownloadOperation class]]) {
                    ONDownloadOperation *dop1 = (ONDownloadOperation *)op1;
                    ONDownloadOperation *dop2 = (ONDownloadOperation *)op2;
                    
                    result = [[NSNumber numberWithInt:dop2.downloadItem.priority] 
                              compare:[NSNumber numberWithInt:dop1.downloadItem.priority]];
                }
            }
            
            if (result != NSOrderedSame) {
                result = [op1.category compare:op2.category];
            }
            
            return result;
        }
        
        // fall through in case object types do not match
        return (NSComparisonResult)NSOrderedSame;
    }];
    
    return sorted;
}

- (void)didStartNetworking {
    networkingCount += 1;
    
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
}

- (void)didStopNetworking {
    if (networkingCount > 0) {
        networkingCount -= 1;
    }
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible: (networkingCount > 0)];
}

- (NSUInteger)operationsCount {
    return self.queuedCount;
}

@end
