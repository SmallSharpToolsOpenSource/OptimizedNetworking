OptimizedNetworking
===================

### iOS project using NSOperationQueue for optimal networking

### Overview

This project is meant to provide a simple way to optimize networking with a focus on using NSOperationQueue
versus simply using the async API of NSURLConnection or using GCD to offload work to a secondary queue which
has less control over the number of concurrent connections and the ability to cancel. Batch downloads of multiple
files (images) is the focus of this project initially with potential updates to focus on API communications
with retries and resume operations.

Reference projects include MVCNetworking and AFNetworking. These projects have a different focus and have
a much broader scope which makes them harder to understand. With Optimized Networking my goal is to understand
the different performance realities with NSOperationQueue and GCD with the number of allowed concurrent
operations. Based on WWDC 2010 session 207 and 208 it has been preferred to use NSOperationQueue while GCD
may be ready to be used after GCD has matured more. Is it ready? What can be done about limiting connections?
What about cancellation? What about priorities?

The download operations work with a DownloadItem object which is given a priority which translates into a 
priority on the queue. It also influences the sort of the operations before they are added to the networking
queue to be processed. Items can be added with a category so they can be cancelled by the category. These 
categories could allow for some flexibility with managing performance and reducing excessive bandwidth use.

Another approach that I have already used is to use the async API of NSURLConnection with a notification
which is able to trigger all downloads to be cancelled immediately. This is a broad approach which is made
more precise with categories and prioritizing downloads.

* [MVCNetworking Sample Project](http://developer.apple.com/library/ios/#samplecode/MVCNetworking/Introduction/Intro.html)
* [AFNetworking Project](https://github.com/AFNetworking/AFNetworking)

### Questions

My current download solution works with Blocks and the async API of NSURLConnection and an array
of download items. As each download finishes it starts downloading the next item in a sequential way.
Downloads are not concurrent. With NSOperationQueue connections are conncurrent and can be set to 1,
2, 4, 8, 16 or any arbitrary count. Various combinations of settings will be used to determine the optimal
way to download a batch of images. The test data is currently using the Flickr search API. The duration
of each download and the total duration for all files will help identify an optimal way of downloading
several images.

Bandwidth is one factor while processing power is as well. With the async API of NSURLConnection really
doing most of the work inside of the operation with isolation it should be using minimal processor
cycles to do the job. With the number of concurrent operations limited it should also cut down on 
processor needs and be limited mostly by bandwidth.

Finally, it could be possible to switch to GCD entirely if it is possible to show that a single queue
can be limited to a number of executing blocks to control the number of network connections. It is still
possible to cancel connections using notifications, so that may become the way make that work to get the
same advantages provided by NSOperationQueue with having to use NSRunLoop and deal with other issues 
that come up with thread isolation. There may be some concerns with using GCD in this way. Measuring
the performance and speed of both approaches should help to identify the optimal way to quickly
download files and later do other network communications.

### How it Works

Working with threads is hard and often the source of many problems so Apple created NSOperationQueue to
help developers avoid the headaches of thread programming. Perhaps it is easier but working with
NSOperationQueue was not as trivial as I thought it would be.

First I have an NSOperationQueue and then a class which derives from NSOperation which is effectively an
abstract class that you are meant to inherit. This operation class has various properties to relay the
state of the operation and the queue makes use Key Value Observation to determine when an operation is
ready, executing and finished. Changing the status requires calling changeStatus: which makes the calls
needed for KVO. Another very important details is the fact that this operation is set to run concurrently
which is set with the isConcurrent property. Using the async API of NSURLConnection means this operation
is concurrent which means it will need to use an NSRunLoop to process callbacks. Since an operation runs
in an isolated thread the run loop is used to process callbacks. And to line everything up the operation
has to run on the same thread, which is not the main thread, which is also running the NSRunLoop.You can
see all these details in the MVCNetworking sample project from Apple although it adds a lot more details
beyond the focus of this project.

* [Managing Concurrency with NSOperation](https://developer.apple.com/library/mac/#featuredarticles/ManagingConcurrency/_index.html)
* [Introduction to Key-Value Observing Programming Guide](https://developer.apple.com/library/mac/#documentation/Cocoa/Conceptual/KeyValueObserving/KeyValueObserving.html)
* [NSRunLoop Class Reference](https://developer.apple.com/library/mac/#documentation/Cocoa/Reference/Foundation/Classes/NSRunLoop_Class/Reference/Reference.html)

