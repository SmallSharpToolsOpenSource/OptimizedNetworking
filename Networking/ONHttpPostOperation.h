//
//  ONPostJsonOperation.h
//  OptimizedNetworking
//
//  Created by Brennan Stehling on 3/6/13.
//  Copyright (c) 2013 SmallSharpTools LLC. All rights reserved.
//

#import "ONNetworkOperation.h"

@interface ONHttpPostOperation : ONNetworkOperation

+ (void)addHttpPostOperationWithURL:(NSURL *)url
                  completionHandler:(ONNetworkOperationCompletionHandler)completionHandler
                    progressHandler:(ONNetworkOperationProgressHandler)progressHandler;

@end
