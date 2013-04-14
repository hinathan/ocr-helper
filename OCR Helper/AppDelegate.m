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

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    id object = [[NSUserDefaults standardUserDefaults] objectForKey:kPrefWatchPath];
    if(object) {
        NSURL *url = [NSURL fileURLWithPath:(NSString *)object];
        NSLog(@"preference URL is %@ string was %@", url, object);
        [self.pathControl setURL:url];
    } else {
        NSLog(@"no preference?");
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
    
    NSURL *URL = [NSURL URLFromPasteboard:[info draggingPasteboard]];
    if (URL != nil)
    {
        [self.pathControl setURL:URL];
        NSString *str = [NSString stringWithFormat:@"Watching path %@",[URL path]];
        [self.statusText setStringValue:str];
        [[NSUserDefaults standardUserDefaults] setObject:[URL path] forKey:kPrefWatchPath];

        result = YES;
    }
    
    return result;
}

@end
