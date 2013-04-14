//
//  AppDelegate.m
//  OCR Helper
//
//  Created by Nathan Schmidt on 4/13/13.
//  Copyright (c) 2013 Nathan Schmidt. All rights reserved.
//

#import "AppDelegate.h"


NSString *const kPrefWatchPath = @"pref~WatchPath";

@implementation AppDelegate

FSEventStreamRef stream;
AppDelegate *instance;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    id object = [[NSUserDefaults standardUserDefaults] objectForKey:kPrefWatchPath];
    if(!object) {
        return;
    }
    NSURL *url = [NSURL fileURLWithPath:(NSString *)object];
    if(!url) {
        return;
    }
    [self.pathControl setURL:url];
    [self beginWatchingURL:url];
    instance = self;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    FSEventStreamUnscheduleFromRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
}


void myCallbackFunction(
                ConstFSEventStreamRef streamRef,
                void *clientCallBackInfo,
                size_t numEvents,
                void *eventPaths,
                const FSEventStreamEventFlags eventFlags[],
                const FSEventStreamEventId eventIds[])
{
    [instance findFilesToRun];
    return;
    
    int i;
    char **paths = eventPaths;
    
    for (i=0; i<numEvents; i++) {
        /* flags are unsigned long, IDs are uint64_t */
        NSLog(@"Change %llu in %s, flags %u\n", eventIds[i], paths[i], eventFlags[i]);
    }

}

-(void)findFilesToRun {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *dirContents = [fm contentsOfDirectoryAtPath:self.pathControl.URL.path error:nil];
    NSPredicate *fltr = [NSPredicate predicateWithFormat:@"self ENDSWITH '.pdf'"];
    NSArray *onlyPDFs = [dirContents filteredArrayUsingPredicate:fltr];
    if([onlyPDFs count]) {
        NSLog(@"PDFS: %@", onlyPDFs);
    }
}

-(void)beginWatchingURL:(NSURL *)url {
    NSString *path = [url path];
    BOOL isDirectory;
    if(![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory]) {
        return;
    }
    if(!isDirectory) {
        return;
    }
    
    NSArray *paths = @[path];

    CFAbsoluteTime latency = 2.0; /* Latency in seconds */
    
    /* Create the stream, passing in a callback */
    stream = FSEventStreamCreate(NULL,
                                 &myCallbackFunction,
                                 NULL,
                                 (__bridge CFArrayRef)paths,
                                 kFSEventStreamEventIdSinceNow, /* Or a previous event ID */
                                 latency,
                                 kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagIgnoreSelf
                                 );

    FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(),         kCFRunLoopDefaultMode);
    FSEventStreamStart(stream);

    NSString *str = [NSString stringWithFormat:@"Watching path %@",path];
    [self.statusText setStringValue:str];

}


// path control delegate
- (NSDragOperation)pathControl:(NSPathControl *)pathControl validateDrop:(id < NSDraggingInfo >)info {
    
    NSPasteboard *pboard = [info draggingPasteboard];
    if ( [[pboard types] containsObject:NSFilenamesPboardType] ) {
        NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];
        if([files count] != 1) {
            return NSDragOperationNone;
        }
        NSString *file = [files objectAtIndex:0];
        
        BOOL isDirectory;
        [[NSFileManager defaultManager] fileExistsAtPath:file isDirectory:&isDirectory];

        if(isDirectory) {
            return NSDragOperationCopy;
        }
    }
    
    return NSDragOperationNone;
}

-(BOOL)pathControl:(NSPathControl *)pathControl acceptDrop:(id <NSDraggingInfo>)info
{
    BOOL result = NO;
    
    NSURL *url = [NSURL URLFromPasteboard:[info draggingPasteboard]];
    if (url != nil)
    {
        [self.pathControl setURL:url];
        [[NSUserDefaults standardUserDefaults] setObject:[url path] forKey:kPrefWatchPath];
        [self beginWatchingURL:url];
        result = YES;
    }
    
    return result;
}

@end
