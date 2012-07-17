//
//  ONViewController.m
//  OptimizedNetworking
//
//  Created by Brennan Stehling on 7/10/12.
//  Copyright (c) 2012 SmallSharpTools LLC. All rights reserved.
//

#import "ONViewController.h"

#import "ONNetworking.h"
#import "ONFlickrPhotoSetParser.h"

#define kFlickBaseUrl                       @"http://api.flickr.com/services/rest/?method="
#define kFlickrApiKey                       @"05476dc1f835d1d07b78f2b19f2de809"

// Search Flickr for orchid
// kFlickBaseUrl + flickr.photos.search&api_key=%@&is_commons=true&text=sunset&per_page=100

#pragma mark - Class Extension
#pragma mark -

@interface ONViewController () <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UIImageView *sampleImageView;
@property (weak, nonatomic) IBOutlet UITextField *searchTextField;
@property (weak, nonatomic) IBOutlet UISegmentedControl *connectionsCountSegmentedControl;

@property (weak, nonatomic) IBOutlet UILabel *totalDownloadsLabel;
@property (weak, nonatomic) IBOutlet UILabel *totalQueuedLabel;
@property (weak, nonatomic) IBOutlet UILabel *totalErrorsLabel;
@property (weak, nonatomic) IBOutlet UILabel *averageDownloadTimeLabel;

@property (strong, nonatomic) NSMutableArray *downloadDurations;

- (IBAction)startDownloadsTapped:(id)sender;

- (void)downloadFlickrSearch;

@end

#pragma mark -

@implementation ONViewController {
    NSUInteger totalDownloads;
    NSUInteger totalQueued;
    NSUInteger totalErrors;
}

@synthesize downloadDurations = _downloadDurations;

#pragma mark - Properties
#pragma mark -

@synthesize sampleImageView = _sampleImageView;
@synthesize searchTextField = _searchTextField;
@synthesize connectionsCountSegmentedControl = _connectionsCountSegmentedControl;
@synthesize totalDownloadsLabel = _totalDownloadsLabel;
@synthesize totalQueuedLabel = _totalQueuedLabel;
@synthesize totalErrorsLabel = _totalErrorsLabel;
@synthesize averageDownloadTimeLabel = _averageDownloadTimeLabel;

- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    self.downloadDurations = [NSMutableArray array];
}

- (void)viewDidUnload {
    // Release any retained subviews of the main view.
    [self setSampleImageView:nil];
    [self setSearchTextField:nil];
    [self setConnectionsCountSegmentedControl:nil];
    [self setTotalDownloadsLabel:nil];
    [self setTotalQueuedLabel:nil];
    [self setTotalErrorsLabel:nil];
    [self setAverageDownloadTimeLabel:nil];
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - User Actions
#pragma mark -

- (IBAction)startDownloadsTapped:(id)sender {
    DebugLog(@"Starting Downlads");
    [self downloadFlickrSearch];
}

#pragma mark - Private Methods
#pragma mark -

- (void)downloadFlickrSearch {
    [[ONNetworkManager sharedInstance] cancelAll];
    
    NSString *urlString = [NSString stringWithFormat:@"%@flickr.photos.search&api_key=%@&is_commons=true&text=%@&per_page=50", 
                           kFlickBaseUrl, kFlickrApiKey, [self encodedSearchText]];
    NSURL *url = [NSURL URLWithString:urlString];
    DebugLog(@"Searching (%@) - %@", self.searchTextField.text, urlString);
    ONDownloadItem *downloadItem = [[ONDownloadItem alloc] initWithURL:url];
    
    ONDownloadOperation *downloadOperation = [[ONDownloadOperation alloc] initWithDownloadItem:downloadItem];
    [downloadOperation setCompletionHandler:^(NSData *data, NSError *error) {
        if (error != nil) {
            DebugLog(@"Error: %@", error);
        }
        else {
            ONFlickrPhotoSetParser *parser = [[ONFlickrPhotoSetParser alloc] init];
            [parser parseWithData:data withCompletionBlock:^(NSArray *imageUrls, NSError *error) {
                DebugLog(@"Found %i images to download from Flickr", imageUrls.count);
                [self downloadImages:imageUrls];
            }];
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.25 * NSEC_PER_SEC), dispatch_get_current_queue(), ^{
                DebugLog(@"There are %i operations in the networking queue.", [[ONNetworkManager sharedInstance] operationsCount]);
            });
        }
    }];
    
    [[ONNetworkManager sharedInstance] addOperation:downloadOperation];
}

- (void)downloadImages:(NSArray *)urlStrings {
    [[ONNetworkManager sharedInstance] setMaxConcurrentOperationCount:[self connectionsCount]];
    
    totalDownloads = 0;
    totalQueued = 0;
    totalErrors = 0;
    [self.downloadDurations removeAllObjects];
    
    totalDownloads = urlStrings.count;
    
    NSMutableArray *downloadOperations = [NSMutableArray array];
    for (NSString *urlString in urlStrings) {
        NSURL *url = [NSURL URLWithString:urlString];
        ONDownloadItem *downloadItem = [[ONDownloadItem alloc] initWithURL:url];
        ONDownloadOperation *operation = [[ONDownloadOperation alloc] initWithDownloadItem:downloadItem];
        __weak ONDownloadOperation *weakOperation = operation;
        [operation setCompletionHandler:^(NSData *data, NSError *error) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.25 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                
                [self.downloadDurations addObject:[NSNumber numberWithFloat:[weakOperation operationDuration]]];
                totalQueued = [[ONNetworkManager sharedInstance] operationsCount];
                
                if (error != nil) {
                    DebugLog(@"Error: %@", error);
                    totalErrors++;
                }
                else {
                    // change the data into an image and display it to show progress
                    UIImage *image = [UIImage imageWithData:data];
                    self.sampleImageView.image = image;
                }
                
                [self updateUI];
            });
        }];
        
        [downloadOperations addObject:operation];
    }
    
    DebugLog(@"Adding operations");
    [[ONNetworkManager sharedInstance] addOperations:downloadOperations];
    
    totalQueued = [[ONNetworkManager sharedInstance] operationsCount];
    [self updateUI];
}

- (void)updateUI {
    dispatch_async(dispatch_get_main_queue(), ^{
        @synchronized (self) {
            self.totalDownloadsLabel.text = [NSString stringWithFormat:@"%i", totalDownloads];
            self.totalQueuedLabel.text = [NSString stringWithFormat:@"%i", totalQueued];
            self.totalErrorsLabel.text = [NSString stringWithFormat:@"%i", totalErrors];
            self.averageDownloadTimeLabel.text = [NSString stringWithFormat:@"%3.2f", [self calculatedAverageDownloadDuration]];
            
            if (totalErrors > 0) {
                self.totalErrorsLabel.textColor = [UIColor redColor];
            }
            else {
                self.totalErrorsLabel.textColor = [UIColor blackColor];
            }
        }
    });
}

- (NSTimeInterval)calculatedAverageDownloadDuration {
    DebugLog(@"Calculating average duration for %i durations", self.downloadDurations.count);
    if (self.downloadDurations.count == 0) {
        return 0.0;
    }
    @synchronized (self) {
        CGFloat totalDuration = 0.0;
        for (NSNumber *duration in self.downloadDurations) {
            totalDuration += [duration floatValue];
        }
        return totalDuration / self.downloadDurations.count;
    }
}

- (NSString *)encodedSearchText {
    NSString *urlEncodedString = self.searchTextField.text;
    
    if (urlEncodedString == nil || [@"" isEqualToString:urlEncodedString]) {
        urlEncodedString = @"sunset";
    }
    
    CFStringRef ref = CFURLCreateStringByAddingPercentEscapes( NULL,
                                                              (__bridge CFStringRef)urlEncodedString,
                                                              NULL,
                                                              (CFStringRef)@"!*'();:@&=+$,/?%#[]",
                                                              kCFStringEncodingUTF8 );
    
    NSString * encoded = [NSString stringWithString: (__bridge NSString *)ref];
    CFRelease(ref);
    
    return encoded;
}

- (NSUInteger)connectionsCount {
    NSUInteger connectionsCount = 0;
    
    switch (self.connectionsCountSegmentedControl.selectedSegmentIndex) {
        case 0:
            connectionsCount = 1;
            break;
        case 1:
            connectionsCount = 2;
            break;
        case 2:
            connectionsCount = 4;
            break;
        case 3:
            connectionsCount = 8;
            break;
            
        default:
            break;
    }
    
    return connectionsCount;
}

#pragma mark - UITextFieldDelegate
#pragma mark -

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self.searchTextField resignFirstResponder];
    
    return YES;
}

@end
