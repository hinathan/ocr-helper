//
//  DirectoryClassifier.m
//  OCR Helper
//
//  Created by Nathan Schmidt on 4/20/13.
//  Copyright (c) 2013 Nathan Schmidt. All rights reserved.
//

#import "DirectoryClassifier.h"
#import "TextProcessing.h"
#import <PDFKit/PDFKit.h>
#import <CommonCrypto/CommonDigest.h>
#import "Bayes.h"
#import "AppDelegate.h"


@implementation DirectoryClassifier

NSMutableDictionary *checkedCacheExists;
Bayes *classifier;
NSInteger initialOperationCount;
NSOperationQueue *queue;
AppDelegate *delegate;
int n = 4;



-(id)init {
    self = [super init];
    classifier = [[Bayes alloc] init];
    queue = [[NSOperationQueue alloc] init];
    [queue setMaxConcurrentOperationCount:1];
    delegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
    checkedCacheExists = [[NSMutableDictionary alloc] init];
    return self;
}


-(void)classifyPDF:(NSString *)path completion:(void (^)(NSArray *guesses,NSString *mostLike))completionHandler {
    NSArray *tokens = [self tokensForPath:path];
    //NSLog(@"TOKENS FOR GUESS %@",tokens);
    NSLog(@"start guess");
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        [classifier guessNaiveBayes:tokens];
        NSLog(@"finish guess");
        //    [classifier guessRobinson:tokens];
    //    NSLog(@"guessNaiveBayes %@", classifier.probabilities);
        //NSLog(@"guessRobinson %@", classifier.probabilities);
        
        
        NSArray *reverseRanked = [classifier.probabilities keysSortedByValueUsingSelector:@selector(compare:)];
        unsigned long want = MIN([reverseRanked count],6);
        NSRange range = NSMakeRange([reverseRanked count] - want,want);
        NSArray *ranked = [reverseRanked subarrayWithRange:range];
        
    //    NSLog(@"probs: %@",classifier.probabilities);
        NSLog(@"scores for %@", path);
        
        NSMutableArray *pretty = [[NSMutableArray alloc] init];
        for(NSString *path in ranked) {
            NSString *scored = [NSString stringWithFormat:@"%@\t%@", [classifier.probabilities objectForKey:path],[path lastPathComponent]];
            [pretty insertObject:scored atIndex:0];
        }

        NSDictionary *docScores = [self checkDirectories:ranked forPdf:path];
        NSArray *reverseRankedDocs = [docScores keysSortedByValueUsingSelector:@selector(compare:)];
        
        NSLog(@"document scores: %@", docScores);
        
        NSString *mostLike = [reverseRankedDocs lastObject];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(pretty,mostLike);
        });
    });
}

-(NSString *)cacheDirectory:(NSString *)subdir {
    NSString *path = nil;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *bundleName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
    path = [[paths objectAtIndex:0] stringByAppendingPathComponent:bundleName];
    path = [path stringByAppendingPathComponent:subdir];
    if(![checkedCacheExists objectForKey:path]) {
        NSError *error;
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error];
        [checkedCacheExists setValue:path forKey:path];
    }

    return path;
}

-(NSString *)hash:(NSString *)input {
    const char *cstr = [input cStringUsingEncoding:NSUTF8StringEncoding];
    NSData *data = [NSData dataWithBytes:cstr length:input.length];

    uint8_t digest[CC_SHA1_DIGEST_LENGTH];

    CC_SHA1(data.bytes, (unsigned int)data.length, digest);

    NSMutableString* output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];

    for(int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", digest[i]];
    }
    return output;
}

-(void)recursivelyScanDirectory:(NSString *)directory exclude:(NSArray *)excludeDirectories {
//    if([excludeDirectories containsObject:directory]) {
 //       return;
  //  }
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:directory];
    NSMutableArray *scanQueue = [[NSMutableArray alloc] initWithObjects:nil];
    
    for (NSString *path in enumerator) {
        NSString *fullPath = [directory stringByAppendingPathComponent:path];
        BOOL isDirectory = NO;
        if ([[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDirectory] && isDirectory) {
            if([excludeDirectories containsObject:fullPath]) {
                //NSLog(@"EXCLUDE %@", fullPath);
                continue;
            }
            [scanQueue addObject:fullPath];
            //NSLog(@" ** %@", fullPath);
       //     [self scanDirectory:fullPath];
        }
    }
    
    for(NSString *path in scanQueue) {
        NSInvocationOperation* op = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(scanDirectory:) object:path];
        [queue addOperation:op];
    }
    initialOperationCount = [scanQueue count];
    [delegate setProgress:initialOperationCount-[queue operationCount] total:initialOperationCount];

    [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(pip:) userInfo:nil repeats:YES];
}

-(void)pip:(NSTimer *)timer {
    //NSString *str = [NSString stringWithFormat:@"ops left: %u", (unsigned int)[queue operationCount]];
    dispatch_async(dispatch_get_main_queue(), ^{
        [delegate setProgress:initialOperationCount-[queue operationCount] total:initialOperationCount];
        //[delegate status:str];
        if(![queue operationCount]) {
            NSLog(@"complete...");
            [timer invalidate];
            [delegate setProgress:0 total:0];
            [delegate ready];
        }
    });
    
}

-(void)scanDirectory:(NSString *)directory {
    //NSLog(@"process %@",directory);
//    NSLog(@"scan dir %d %@", [[NSThread currentThread] isMainThread], directory);
    //NSString *str = [NSString stringWithFormat:@"%u %@", (unsigned int)[queue operationCount], directory];
    //dispatch_async(dispatch_get_main_queue(), ^{
      //  [delegate status:str];
    // });

    NSString *cacheDir = [self cacheDirectory:[NSString stringWithFormat:@"bundles%d",n]];
    NSString *hash = [self hash:directory];
    NSString *cachePath = [cacheDir stringByAppendingPathComponent:[hash stringByAppendingString:@".cache"]];
    //NSLog(@"CACHE %@ FOR %@",cacheDir,hash);
    //NSLog(@"CACHE PATH THUS %@",cachePath);

    NSMutableDictionary *cache = [[NSMutableDictionary alloc] initWithContentsOfFile:cachePath];
    if(!cache) {
        cache = [[NSMutableDictionary alloc] initWithObjectsAndKeys:nil];
        NSArray *files = [[NSArray alloc] init];
        [cache setValue:files forKey:@"files"];
        [cache setValue:@[] forKey:@"tokens"];
    }

    NSArray *tokens = [self updateTokensForDirectory:directory inCache:cache];
    NSArray *useTokens = nil;
    
    if(tokens) {
        [cache setValue:tokens forKey:@"tokens"];
        useTokens = tokens;
    } else {
        useTokens = [cache valueForKey:@"tokens"];
    }
    
    //NSLog(@"%d tokens for %@", (int)[useTokens count], directory);
    [classifier train:useTokens forlabel:directory];

    //should only do this if changes...
    if(tokens) {
        [cache writeToFile:cachePath atomically:YES];
    }
    [delegate setProgress:initialOperationCount-[queue operationCount] total:initialOperationCount];
}

-(NSArray *)pdfsInDirectory:(NSString *)directory {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *dirContents = [fm contentsOfDirectoryAtPath:directory error:nil];
    NSPredicate *fltr = [NSPredicate predicateWithFormat:@"self ENDSWITH '.pdf'"];
    return [dirContents filteredArrayUsingPredicate:fltr];
}

-(NSArray *)updateTokensForDirectory:(NSString *)directory inCache:(NSMutableDictionary *)cache {
    NSMutableArray *tokens = [[NSMutableArray alloc] initWithObjects:nil];
    NSArray *onlyPDFs = [self pdfsInDirectory:directory];
    
    NSArray *cachedFiles = (NSArray *)[cache valueForKey:@"files"];
    if(cachedFiles && [onlyPDFs isEqualToArray:cachedFiles]) {
        //NSLog(@"Complete cache %@", directory);
        return nil;
    } else {
        NSLog(@"Building index %@", directory);
    }
    for(NSString *pdf in onlyPDFs) {
        NSString *path = [directory stringByAppendingFormat:@"/%@",pdf];
        NSArray *pdfTokens = [self tokensForPath:path];
        [tokens addObjectsFromArray:pdfTokens];
    }
    [cache setValue:onlyPDFs forKey:@"files"];
    return tokens;
}


-(NSDictionary *)checkDirectories:(NSArray *)directories forPdf:(NSString *)pdf {
    NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
    NSArray *tokens = [self tokensForPath:pdf];
    for(NSString *dir in directories) {
        Bayes *classifier = [self trainedClassifierForDirectoy:dir];
        [classifier guessNaiveBayes:tokens];
        [result addEntriesFromDictionary:classifier.probabilities];
    }
    return result;
}

-(Bayes *)trainedClassifierForDirectoy:(NSString *)directory {
    NSArray *pdfs = [self pdfsInDirectory:directory];
    Bayes *classifier = [[Bayes alloc] init];
    for(NSString *pdf in pdfs) {
        NSString *path = [directory stringByAppendingPathComponent:pdf];
        NSArray *tokens = [self tokensForPath:path];
        [classifier train:tokens forlabel:path];
    }
    return classifier;
}

-(NSArray *)tokensForPath:(NSString *)path {
    NSString *cacheDir = [self cacheDirectory:[NSString stringWithFormat:@"docs%d",n]];
    NSString *hash = [self hash:path];
    NSString *cachePath = [cacheDir stringByAppendingPathComponent:[hash stringByAppendingString:@".cache"]];
    NSArray *pdfTokens = @[];
    NSDictionary *cache;
    if([[NSFileManager defaultManager] fileExistsAtPath:cachePath]) {
        //NSLog(@"HAVE cache for %@ at %@",path,cachePath);
        cache = [[NSDictionary alloc] initWithContentsOfFile:cachePath];
        if(cache) {
            return [cache valueForKey:@"tokens"];
        }
    }
    cache = [[NSMutableDictionary alloc] init];
    [cache setValue:path forKey:@"source"];
    //NSLog(@"MAKING cache for %@ at %@",path,cachePath);
    NSURL *url = [NSURL fileURLWithPath: path];
    PDFDocument *pdfDoc = [[PDFDocument alloc] initWithURL:url];
    if(pdfDoc) {
        NSString *stringValue = [pdfDoc string];
        if([stringValue length]) {

            NSRange stringRange = {0, MIN([stringValue length], 4096)};
            stringRange = [stringValue rangeOfComposedCharacterSequencesForRange:stringRange];
            // Now you can create the short string
            stringValue = [stringValue substringWithRange:stringRange];

            pdfTokens = [self tokenizeString:stringValue n:n];
        }
    }
    //NSLog(@"WRITE cache for %@ at %@",path,cachePath);
    [cache setValue:pdfTokens forKey:@"tokens"];
    [cache writeToFile:cachePath atomically:YES];
    //NSLog(@"WROTE");

    return pdfTokens;
}

-(NSArray *)tokenizeString:(NSString *)string n:(int)n {
    NSString *stripped = [TextProcessing removePunctuations:string];
    NSString *stopped = [TextProcessing removeStopwords:stripped];
    if(n == 4) {
        return [TextProcessing fourgrams:stopped];
    } else if(n == 3) {
        return [TextProcessing trigrams:stopped];
    } else if(n == 2){
        return [TextProcessing bigrams:stopped];
    } else {
        exit(EXIT_FAILURE);
    }
}



@end
