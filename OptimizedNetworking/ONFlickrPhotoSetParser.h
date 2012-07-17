//
//  ONFlickrPhotoSetParser.h
//  OptimizedNetworking
//
//  Created by Brennan Stehling on 7/16/12.
//  Copyright (c) 2012 SmallSharpTools LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ONFlickrPhotoSetParser : NSObject

- (void)parseWithData:(NSData *)data withCompletionBlock:(void (^)(NSArray *imageUrls, NSError *error))completionBlock;

@end
