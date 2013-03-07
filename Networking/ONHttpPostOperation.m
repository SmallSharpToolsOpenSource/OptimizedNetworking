//
//  ONPostJsonOperation.m
//  OptimizedNetworking
//
//  Created by Brennan Stehling on 3/6/13.
//  Copyright (c) 2013 SmallSharpTools LLC. All rights reserved.
//

#import "ONHttpPostOperation.h"

#import "ONNetworkManager.h"

#define kDefaultHttpMethod              @"POST"

@implementation ONHttpPostOperation

- (NSString *)httpMethod {
    return kDefaultHttpMethod;
}

+ (void)addHttpPostOperationWithURL:(NSURL *)url
                  completionHandler:(ONNetworkOperationCompletionHandler)completionHandler
                    progressHandler:(ONNetworkOperationProgressHandler)progressHandler {
    ONHttpPostOperation *operation = [[ONHttpPostOperation alloc] init];
    operation.url = url;
    operation.completionHandler = completionHandler;
    operation.progressHandler = progressHandler;
    
    [[ONNetworkManager sharedInstance] addOperation:operation];
}

@end
