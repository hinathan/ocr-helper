//
//  AppDelegate.h
//  OCR Helper
//
//  Created by Nathan Schmidt on 4/13/13.
//  Copyright (c) 2013 Nathan Schmidt. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <PDFKit/PDFKit.h>

@interface AppDelegate : NSObject <NSApplicationDelegate,   NSPathControlDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSPathControl *pathControl;
@property (weak) IBOutlet NSTextField *statusText;
-(void)status:(NSString *)status;
-(void)ready;
@property (weak) IBOutlet NSProgressIndicator *progress;
@property (weak) IBOutlet PDFView *pdfViewGuess;
-(void)setProgress:(NSInteger)done total:(NSInteger)total;
@property (weak) IBOutlet PDFView *pdfView;
@property (weak) IBOutlet NSTextField *textMulti;
@end
