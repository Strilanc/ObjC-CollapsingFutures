#import "TOCFutureArrayUtil.h"
#import "TOCCommonDefs.h"

@implementation NSArray (TOCFutureArrayUtil)

-(TOCFuture*) finallyAll {
    NSArray* futures = [self copy]; // remove volatility (i.e. ensure not externally mutable)
    for (TOCFuture* item in futures) {
        require([item isKindOfClass:[TOCFuture class]]);
    }
    
    TOCFutureSource* resultSource = [TOCFutureSource new];
    
    __block NSUInteger remaining = [futures count] + 1;
    NSObject* lock = [NSObject new];
    TOCFutureFinallyHandler doneHandler = ^(TOCFuture *completed) {
        @synchronized(lock) {
            remaining--;
            if (remaining > 0) return;
        }
        
        [resultSource forceSetResult:futures];
    };
    
    for (TOCFuture* item in futures) {
        [item finallyDo:doneHandler];
    }
    
    doneHandler(nil);
    
    return resultSource.future;
}

-(TOCFuture*) thenAll {
    return [[self finallyAll] then:^id(NSArray* completedFutures) {
        NSMutableArray* results = [NSMutableArray array];
        for (TOCFuture* item in completedFutures) {
            if ([item hasFailed]) return [TOCFuture futureWithFailure:completedFutures];
            [results addObject:[item forceGetResult]];
        }
        return results;
    }];
}

-(NSArray*) orderedByCompletion {
    NSArray* futures = [self copy]; // remove volatility (i.e. ensure not externally mutable)
    for (TOCFuture* item in futures) {
        require([item isKindOfClass:[TOCFuture class]]);
    }
    
    NSMutableArray* resultSources = [NSMutableArray array];
    
    __block NSUInteger completedCount = 0;
    NSObject* lock = [NSObject new];
    TOCFutureFinallyHandler doneHandler = ^(TOCFuture *completed) {
        NSUInteger i;
        @synchronized(lock) {
            i = completedCount++;
        }
        [resultSources[i] forceSetResult:completed];
    };
    
    for (TOCFuture* item in futures) {
        [resultSources addObject:[TOCFutureSource new]];
        [item finallyDo:doneHandler];
    }
    
    NSMutableArray* results = [NSMutableArray array];
    for (TOCFutureSource* source in resultSources) {
        [results addObject:source.future];
    }
    return [results copy];
}

@end
