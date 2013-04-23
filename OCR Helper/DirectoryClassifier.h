//
//  DirectoryClassifier.h
//  OCR Helper
//
//  Created by Nathan Schmidt on 4/20/13.
//  Copyright (c) 2013 Nathan Schmidt. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DirectoryClassifier : NSObject
-(void)recursivelyScanDirectory:(NSString *)directory exclude:(NSArray *)excludeDirectories;
-(void)classifyPDF:(NSString *)path completion:(void (^)(NSArray *guesses, NSString *mostLike))completionHandler;

@end
