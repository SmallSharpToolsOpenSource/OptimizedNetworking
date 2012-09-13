//
//  ONDownloadItem.m
//  OptimizedNetworking
//
//  Created by Brennan Stehling on 7/10/12.
//  Copyright (c) 2012 SmallSharpTools LLC. All rights reserved.
//

#import "ONDownloadItem.h"

#import "ONNetworkManager.h"
#import "ONDownloadOperation.h"
#import "ONNetworkOperation.h"

#define kEmptyCacheKey  @"";

@implementation ONDownloadItem

#pragma mark - Initializers
#pragma mark -

- (id)initWithURL:(NSURL *)url {
    return [self initWithURL:url andPriority:ONDownloadItem_Priority_Medium];
}

- (id)initWithURL:(NSURL *)url andPriority:(ONDownloadItem_Priority)priority {
    self = [super init];
    if (self != nil) {
        self.url = url;
        self.priority = priority;
    }
    return self;
}

#pragma mark - Public Method
#pragma mark -

- (NSString *)cacheKey {
    if (self.url == nil) {
        return kEmptyCacheKey;
    }
    NSMutableString *str = [NSMutableString stringWithString:self.url.absoluteString];
    
    [str replaceOccurrencesOfString:@"://" withString:@"-" options:NSLiteralSearch range:NSMakeRange(0, [str length])];
    [str replaceOccurrencesOfString:@"/" withString:@"-" options:NSLiteralSearch range:NSMakeRange(0, [str length])];
    
    return str;
}

#pragma mark - Static Methods
#pragma mark -

+ (void)addDownloadOperationWithURL:(NSURL *)url
                           priority:(ONDownloadItem_Priority)priority
                           category:(NSString *)category
                  completionHandler:(ONNetworkOperationCompletionHandler)completionHandler {
    [ONDownloadItem addDownloadOperationWithURL:url
                                       priority:priority
                                       category:category
                              completionHandler:completionHandler
                                progressHandler:nil];
}

+ (void)addDownloadOperationWithURL:(NSURL *)url
                           priority:(ONDownloadItem_Priority)priority
                           category:(NSString *)category
                  completionHandler:(ONNetworkOperationCompletionHandler)completionHandler
                    progressHandler:(ONNetworkOperationProgressHandler)progressHandler {
    ONDownloadItem *downloadItem = [[ONDownloadItem alloc] initWithURL:url];
    ONDownloadOperation *downloadOperation = [[ONDownloadOperation alloc] initWithDownloadItem:downloadItem];
    downloadOperation.completionHandler = completionHandler;
    downloadOperation.progressHandler = progressHandler;
    [[ONNetworkManager sharedInstance] addOperation:downloadOperation];
}

#pragma mark - Deprecated
#pragma mark -

+ (void)addDownloadOperationWithURL:(NSURL *)url
                        andPriority:(ONDownloadItem_Priority)priority
                        andCategory:(NSString *)category
              withCompletionHandler:(ONNetworkOperationCompletionHandler)completionHandler {
    [ONDownloadItem addDownloadOperationWithURL:url
                                       priority:priority
                                       category:category
                              completionHandler:completionHandler
                                progressHandler:nil];
}

@end
