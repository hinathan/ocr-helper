//
//  AppDelegate.m
//  OCR Helper
//
//  Created by Nathan Schmidt on 4/13/13.
//  Copyright (c) 2013 Nathan Schmidt. All rights reserved.
//

#import "AppDelegate.h"
#import "DirectoryClassifier.h"


NSString *const kPrefWatchPath = @"pref~WatchPath";

@implementation AppDelegate

FSEventStreamRef stream;
AppDelegate *instance;
NSRunningApplication *ocrApp;
NSMutableDictionary *already;
DirectoryClassifier *dc;
NSArray *pdfs;

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
    [_textMulti setStringValue:@""];
    dc = [[DirectoryClassifier alloc] init];
    [dc recursivelyScanDirectory:@"/Users/nathan/Dropbox/Organized" exclude:@[@"/Users/nathan/Dropbox/Organized/Scanned",@"/Users/nathan/Dropbox/Organized/Unfiled"]];

    pdfs = @[
      @"/Users/nathan/Dropbox/Organized/Scanned/2013_04_20_14_08_42.pdf",
      @"/Users/nathan/Dropbox/Organized/Scanned/2013_04_20_14_09_18.pdf",
      @"/Users/nathan/Dropbox/Organized/Scanned/2013_04_20_14_08_59.pdf",
      ];

}
-(void)ready {
    [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(runTestClassifiers) userInfo:nil repeats:NO];
}

int i = 0;
-(void)runTestClassifiers {
    NSString *pdf = [pdfs objectAtIndex:i];
    if(!pdf) {
        return;
    }
    NSURL *url = [NSURL fileURLWithPath:pdf];
    [_pdfView setDocument:[[PDFDocument alloc] initWithURL:url]];
    [_pdfViewGuess setDocument:nil];
    [_textMulti setStringValue:@"thinking..."];
    [dc classifyPDF:pdf completion:^ (NSArray *guesses, NSString *mostLike) {
        [_textMulti setStringValue:[NSString stringWithFormat:@"Guesses:\n%@",[guesses componentsJoinedByString:@"\n"]]];
        
        NSURL *likeUrl = [NSURL fileURLWithPath:mostLike];
        [_pdfViewGuess setDocument:[[PDFDocument alloc] initWithURL:likeUrl]];
        
        i++;
        if(i < [pdfs count]) {
            [NSTimer scheduledTimerWithTimeInterval:2.0f target:self selector:@selector(runTestClassifiers) userInfo:nil repeats:NO];
        }
    }];
}

-(void)status:(NSString *)status {
    NSLog(@"Status: %@", status);
    [self.statusText setStringValue:status];
}

-(void)setProgress:(NSInteger)done total:(NSInteger)total {
    [_progress setMaxValue:total];
    [_progress setDoubleValue:done];
    if(done == total) {
        [_progress setHidden:YES];
    }
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
}

-(void)findFilesToRun {
    //NSLog(@"findFilesToRun");

    if(ocrApp) {
        if([ocrApp isTerminated]) {
            //done, continue
            NSString *str = [NSString stringWithFormat:@"OCR finished"];
            [self status:str];
            ocrApp = nil;
        } else {
            //still working
            NSString *str = [NSString stringWithFormat:@"OCR running"];
            [self status:str];
            return;
        }
    } else {
        //NSString *str = [NSString stringWithFormat:@"Looking for new PDFs"];
        //[self status:str];
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
        [self status:str];

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
        return NO;
    }
    //NSLog(@"%@ No string, should OCR", url);
    return YES;
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
    [self status:str];

    [NSTimer scheduledTimerWithTimeInterval:5.0f target:self selector:@selector(findFilesToRun) userInfo:nil repeats:YES];
    
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
