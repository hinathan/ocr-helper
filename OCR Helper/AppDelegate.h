//
//  AppDelegate.h
//  OCR Helper
//
//  Created by Nathan Schmidt on 4/13/13.
//  Copyright (c) 2013 Nathan Schmidt. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate,   NSPathControlDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSPathControl *pathControl;
@property (weak) IBOutlet NSTextField *statusText;

@end
