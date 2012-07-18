//
//  ONDownloadOperation.m
//  OptimizedNetworking
//
//  Created by Brennan Stehling on 7/10/12.
//  Copyright (c) 2012 SmallSharpTools LLC. All rights reserved.
//

#import "ONDownloadOperation.h"

#import "ONNetworkManager.h"

#define kONDownloadOperation_CancelNotificationName        @"ONDownloadOperation_CancelNotificationName"
#define kONDownloadOperation_URLNoticationKey              @"ONDownloadOperation_URLNoticationKey"

@interface ONDownloadOperation ()

// observers are retained by the system
@property (nonatomic, assign) id cancelDownloadObserver;

@end

@implementation ONDownloadOperation

@synthesize cancelDownloadObserver = _cancelDownloadObserver;

@synthesize downloadItem = _downloadItem;

- (id)initWithDownloadItem:(ONDownloadItem *)downloadItem {
    return [self initWithDownloadItem:downloadItem andCategory:@"Default"];
}

- (id)initWithDownloadItem:(ONDownloadItem *)downloadItem andCategory:(NSString *)category {
    self = [super init];
    if (self != nil) {
        self.url = downloadItem.url;
        self.downloadItem = downloadItem;
        self.category = category;
        self.status = ONNetworkOperation_Status_Waiting;
        
        if (self.downloadItem.priority == ONDownloadItem_Priority_Low) {
            [self setQueuePriority:NSOperationQueuePriorityLow];
        }
        else if (self.downloadItem.priority == ONDownloadItem_Priority_Medium) {
            [self setQueuePriority:NSOperationQueuePriorityNormal];
        }
        else if (self.downloadItem.priority == ONDownloadItem_Priority_High) {
            [self setQueuePriority:NSOperationQueuePriorityHigh];
        }
    }
    return self;
}

#pragma mark - ONNetworkOperation Overrides
#pragma mark -

- (void)startNetworkOperation {
    DebugLog(@"Starting %@", self);
    
    // NOTE: Networking on the networking queue should not be happening on the main queue
    assert(dispatch_get_main_queue() != dispatch_get_current_queue());
    
    self.cancelDownloadObserver = [[NSNotificationCenter defaultCenter] 
                                   addObserverForName:kONDownloadOperation_CancelNotificationName
                                   object:nil 
                                   queue:[NSOperationQueue mainQueue] 
                                   usingBlock:^(NSNotification *notification) {
                                       NSString *urlString = [[notification userInfo] objectForKey:kONDownloadOperation_URLNoticationKey];
                                       if ([self.downloadItem.url isEqual:[NSURL URLWithString:urlString]]) {
                                           [self cancel];
                                       }
                                   }];
    
    // use the default cache policy to do the memory/disk caching
    NSMutableURLRequest *request = [NSMutableURLRequest 
                                       requestWithURL:self.downloadItem.url 
                                       cachePolicy:NSURLRequestUseProtocolCachePolicy 
                                       timeoutInterval:30];
    
    // ensure a fresh response is returned
    [request setValue:@"Cache-Control" forHTTPHeaderField:@"no-cache"];

    self.connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    [self.connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.connection start];
    
    if (self.connection == nil) {
        /* inform the user that the connection failed */
        
        NSString *errorMessage = [NSString stringWithFormat:@"Error creating connection (%@)", self.downloadItem.url ];
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:errorMessage forKey:NSLocalizedDescriptionKey];
        NSError *error = [NSError errorWithDomain:@"ONNetworkOperationErrorDomain"
                                             code:100
                                         userInfo:userInfo];
        self.completionHandler(nil, error);
        return;
    }
    
    [[ONNetworkManager sharedInstance] didStartNetworking];
}

@end
