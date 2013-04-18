//
//  AppDelegate.m
//  OCR Helper
//
//  Created by Nathan Schmidt on 4/13/13.
//  Copyright (c) 2013 Nathan Schmidt. All rights reserved.
//

#import "AppDelegate.h"
#import <PDFKit/PDFKit.h>


NSString *const kPrefWatchPath = @"pref~WatchPath";

@implementation AppDelegate

FSEventStreamRef stream;
AppDelegate *instance;
NSRunningApplication *ocrApp;
NSMutableDictionary *already;

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
    already = [[NSMutableDictionary alloc] init];
    instance = self;
    ocrApp = nil;
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
        //NSLog(@"Change %llu in %s, flags %u\n", eventIds[i], paths[i], eventFlags[i]);
    }

}

-(void)findFilesToRun {
    //NSLog(@"findFilesToRun");

    if(ocrApp) {
        if([ocrApp isTerminated]) {
            //done, continue
            NSString *str = [NSString stringWithFormat:@"OCR finished"];
            [self.statusText setStringValue:str];
            ocrApp = nil;
        } else {
            //still working
            NSString *str = [NSString stringWithFormat:@"OCR running"];
            [self.statusText setStringValue:str];
            return;
        }
    } else {
        NSString *str = [NSString stringWithFormat:@"Looking for new PDFs"];
        [self.statusText setStringValue:str];
    }

    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dirPath = self.pathControl.URL.path;
    NSArray *dirContents = [fm contentsOfDirectoryAtPath:dirPath error:nil];
    NSPredicate *fltr = [NSPredicate predicateWithFormat:@"self ENDSWITH '.pdf'"];
    NSArray *onlyPDFs = [dirContents filteredArrayUsingPredicate:fltr];

    if(![onlyPDFs count]) {
        //no pdfs.
        return;
    }

    for(NSString *pdf in onlyPDFs) {
        
        NSString *path = [dirPath stringByAppendingFormat:@"/%@",pdf];
        if(![self shouldOCR:path]) {
            continue;
        }
        NSString *str = [NSString stringWithFormat:@"Should OCR %@",pdf];
        [self.statusText setStringValue:str];

        NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
        NSURL *url = [NSURL fileURLWithPath:[workspace fullPathForApplication:@"Scan to Searchable PDF.app"]];
        //NSLog(@"App is at %@", url);
        //NSError *error = nil;
        NSArray *arguments = [NSArray arrayWithObjects:path, nil];
        ocrApp = [workspace launchApplicationAtURL:url options:0 configuration:[NSDictionary dictionaryWithObject:arguments forKey:NSWorkspaceLaunchConfigurationArguments] error:nil];

        return;
    }
}

-(BOOL)shouldOCR:(NSString *)path {
    NSURL *url = [NSURL fileURLWithPath: path];
    if([already objectForKey:path]) {
        //NSLog(@"%@ Already processed", url);
        return NO;
    }
    PDFDocument *pdfDoc = [[PDFDocument alloc] initWithURL:url];
    if(!pdfDoc) {
        //NSLog(@"%@ Invalid PDF", url);
        return NO;
    }
    NSString *done = @"ABBYY FineReader for ScanSnap";
    NSDictionary *attributes = [pdfDoc documentAttributes];
    if(attributes && attributes[PDFDocumentCreatorAttribute]) {
        NSString *creator = attributes[PDFDocumentCreatorAttribute];
        if([creator hasPrefix:done]) {
            //NSLog(@"%@ Already OCRd by ABBYY", url);
            [already setObject:path forKey:path];
            return NO;
        }
    }
    NSString *stringValue = [pdfDoc string];
    if([stringValue length]) {
        [already setObject:path forKey:path];
        return YES;
    }
    //NSLog(@"%@ No string, should OCR", url);
    return NO;
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

    [NSTimer scheduledTimerWithTimeInterval:30.0f target:self selector:@selector(findFilesToRun) userInfo:nil repeats:YES];
    
    NSNotificationCenter *center = [[NSWorkspace sharedWorkspace] notificationCenter];
    [center removeObserver:self];
    [center addObserver:self selector:@selector(appTerminated:) name:NSWorkspaceDidTerminateApplicationNotification object:nil];
}


- (void)appTerminated:(NSNotification *)note {
    NSDictionary *info = [note userInfo];
    //NSLog(@"TERIMINATED INFO: %@", info);
    NSString *app = [NSString stringWithFormat:@"%@", [info objectForKey:@"NSApplicationName"]];
    
    //NSLog(@"APP?: %@", app);

    if ([app hasPrefix:@"Scan to Searchable PDF"]) {
        ocrApp = nil;
        [self findFilesToRun];
    }
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
