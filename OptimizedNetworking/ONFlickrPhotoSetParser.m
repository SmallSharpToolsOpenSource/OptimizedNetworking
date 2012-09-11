//
//  ONFlickrPhotoSetParser.m
//  OptimizedNetworking
//
//  Created by Brennan Stehling on 7/16/12.
//  Copyright (c) 2012 SmallSharpTools LLC. All rights reserved.
//

#import "ONFlickrPhotoSetParser.h"

#define kFlickrApiKey                       @"05476dc1f835d1d07b78f2b19f2de809"

#define kFlickBaseUrl                       @"http://api.flickr.com/services/rest/?method="
#define kFlickrPhotSetGetPhotosMethod       @"flickr.photosets.getPhotos"
#define kFlickrPhotoSetParameters           @"&api_key=%@&photoset_id=%@&nojsoncallback=true"

#define kTag_PhotoSet                       @"photoset"
#define kTag_Photo                          @"photo"

#define kImageURL                           @"http://farm%@.static.flickr.com/%@/%@_%@_z.jpg"

// Small:
// @"http://farm%@.static.flickr.com/%@/%@_%@_m.jpg";
// Medium:
// @"http://farm%@.static.flickr.com/%@/%@_%@.jpg";
// Medium2:
// @"http://farm%@.static.flickr.com/%@/%@_%@_z.jpg";
// Large:
//  @"http://farm%@.static.flickr.com/%@/%@_%@_b.jpg";


@interface ONFlickrPhotoSetParser () <NSXMLParserDelegate> 

@property (strong, nonatomic) NSMutableArray *imageUrls;

@end

@implementation ONFlickrPhotoSetParser

- (void)parseWithData:(NSData *)data withCompletionBlock:(void (^)(NSArray *imageUrls, NSError *error))completionBlock {
    self.imageUrls = [NSMutableArray array];
    
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
    parser.delegate = self;
    [parser parse];
    
    if (parser.parserError != nil) {
        completionBlock(nil, parser.parserError);
    }
    else {
        completionBlock(self.imageUrls, nil);
    }
}

#pragma mark NSXMLParser Parsing Callbacks

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *) qualifiedName attributes:(NSDictionary *)attributeDict {
    if ([elementName isEqualToString:kTag_Photo]) {
        NSString *photoId = [attributeDict objectForKey:@"id"];
        NSString *secret = [attributeDict objectForKey:@"secret"];
        NSString *server = [attributeDict objectForKey:@"server"];
        NSString *farm = [attributeDict objectForKey:@"farm"];
        
        // add url string to self.imageUrls
        NSString *urlString = [NSString stringWithFormat:kImageURL, farm, server, photoId, secret];
        [self.imageUrls addObject:urlString];
    }
}

@end
