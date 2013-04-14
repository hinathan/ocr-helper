//
//  AppDelegate.m
//  OCR Helper
//
//  Created by Nathan Schmidt on 4/13/13.
//  Copyright (c) 2013 Nathan Schmidt. All rights reserved.
//

#import "AppDelegate.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
}



// path control delegate
- (NSDragOperation)pathControl:(NSPathControl *)pathControl validateDrop:(id < NSDraggingInfo >)info {
    
    NSPasteboard *pboard = [info draggingPasteboard];
    if(info) {
        if ( [[pboard types] containsObject:NSFilenamesPboardType] ) {
            NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];
            if([files count] != 1) {
                return NSDragOperationNone;
            }
            NSString *file = [files objectAtIndex:0];
            
            BOOL isDirectory;
            [[NSFileManager defaultManager] fileExistsAtPath:file
                                                 isDirectory:&isDirectory];
            if(isDirectory) {
                return NSDragOperationCopy;
            }
        }
    }
    
    
    return NSDragOperationNone;
    
//    return NSDragOperationNone;
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
//        NSLog(@"URL: %@", URL);
        // If appropriate, tell the user how they can reveal the path component.
//        [self updateExplainText];
        result = YES;
    }
    
    return result;
}

@end
