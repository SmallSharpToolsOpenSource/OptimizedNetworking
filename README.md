OptimizedNetworking
===================

iOS project to show how to use NSOperationQueue for optimal networking.

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