OptimizedNetworking
===================

### iOS project using NSOperationQueue for optimal networking

### Overview

This project is meant to provide a simple way to optimize networking with a focus on using NSOperationQueue
versus simply using the async API of NSURLConnection or using GCD to offload work to a secondary queue which
has less control over the number of concurrent connections and cancellations. Batch downloads of multiple
files (images) is the focus of this project initially with potential updates to focus on API communications
with retries and resume operations.

Reference projects include MVCNetworking and ASIHTTPRequest. These projects have a different focus and have
a much broader scope which makes them harder to understand. With Optimized Networking my goal is to understand
the different performance realities with NSOperationQueue and GCD with the number of allowed concurrent
operations. Based on WWDC 2010 session 207 and 208 it has been preferred to use NSOperationQueue while GCD
may be ready to be used when it is ready. Is it ready? What can be done about limiting connections? What about
cancellation? What about priorities?

The download operations work with a DownloadItem object which is given a priority which translates into a 
priority on the queue. It also influences the sort of the operations before they are added to the networking
queue to be processed. Items can be added with a category so they can be cancelled by the category. These 
categories could allow for some flexibility with managing performance and reducing excessive bandwidth use.

Another approach that I have already used is to use the async API of NSURLConnection with a notification
which is able to trigger all downloads to be cancelled immediately. This is a broad approach which is made
more precise with categories and prioritizing downloads.

* [MVCNetworking Sample Project](http://developer.apple.com/library/ios/#samplecode/MVCNetworking/Introduction/Intro.html)
* [ASIHTTPRequest Project](http://allseeing-i.com/ASIHTTPRequest/)

## Known Issues

Working with NSOperationQueue and NSOperation has not been as expected or as simple as Apple 
documentations and WWDC presentations make it out to be. In the case of networking the operation
is concurrent which complicates how it works. Specifically NSRunLoop has to be understand and 
run to ensure callbacks to the delegates are executed. The MVCNetworking example does not make
it clear how important it is to set up NSRunLoop.

And while this sample app does work most of the time it appears that it stalls at times. It is
possible that the NSRunLoop is not firing and processing callbacks for some reason. I will need
to learn more about NSRunLoop and review other sample projects which use it. Right now I do not
know a good way to debug NSRunLoop to ensure it is running and processing callbacks.

I did just put in a Thread to run the NSRunLoop but more testing needs to be done to ensure
that networking callbacks are fired. Also, the NSRunLoop is set to the default mode. I do not 
see a mode specific to networking in any of the available sample projects. Ideally only
networking callbacks would be processed in the scope of this queue.