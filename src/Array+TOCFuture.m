#import "Array+TOCFuture.h"
#import "TOCFuture+MoreContinuations.h"
#import "TOCInternal.h"
#import "TOCInternal_Array+Functional.h"
#import "TOCInternal_Racer.h"
#include <libkern/OSAtomic.h>

@implementation NSArray (TOCFuture)

-(TOCFuture*) finallyAll {
    return [self finallyAllUnless:nil];
}

-(TOCFuture*) finallyAllUnless:(TOCCancelToken*)unlessCancelledToken {
    NSArray* futures = [self copy]; // remove volatility (i.e. ensure not externally mutable)
    require([self allItemsAreKindOfClass:[TOCFuture class]]);
    
    TOCFutureSource* resultSource = [TOCFutureSource new];
    
    require(futures.count < INT_MAX);
    __block int remaining = (int)futures.count + 1;
    TOCFutureFinallyHandler doneHandler = ^(TOCFuture *completed) {
        if (OSAtomicDecrement32(&remaining) > 0) return;
        [resultSource trySetResult:futures];
    };
    
    for (TOCFuture* item in futures) {
        [item finallyDo:doneHandler
                 unless:unlessCancelledToken];
    }
    
    doneHandler(nil);
    
    [unlessCancelledToken whenCancelledDo:^{ [resultSource trySetFailedWithCancel]; }
                                   unless:resultSource.future.cancelledOnCompletionToken];
    
    return resultSource.future;
}

-(TOCFuture*) thenAll {
    return [self thenAllUnless:nil];
}

-(TOCFuture*) thenAllUnless:(TOCCancelToken*)unlessCancelledToken {
    return [[self finallyAllUnless:unlessCancelledToken] then:^id(NSArray* completedFutures) {
        NSMutableArray* results = [NSMutableArray array];
        for (TOCFuture* item in completedFutures) {
            if (item.hasFailed) return [TOCFuture futureWithFailure:completedFutures];
            [results addObject:item.forceGetResult];
        }
        return results;
    }];
}

-(NSArray*) orderedByCompletion {
    return [self orderedByCompletionUnless:nil];
}

-(NSArray*) orderedByCompletionUnless:(TOCCancelToken*)unlessCancelledToken {
    NSArray* futures = [self copy]; // remove volatility (i.e. ensure not externally mutable)
    require([self allItemsAreKindOfClass:[TOCFuture class]]);
    
    NSMutableArray* resultSources = [NSMutableArray array];
    
    require(futures.count <= INT_MAX);
    __block int nextIndexMinusOne = -1;
    TOCFutureFinallyHandler doneHandler = ^(TOCFuture *completed) {
        NSUInteger i = (NSUInteger)OSAtomicIncrement32Barrier(&nextIndexMinusOne);
        [resultSources[i] forceSetResult:completed];
    };
    
    for (TOCFuture* item in futures) {
        [resultSources addObject:[TOCFutureSource new]];
        [[item unless:unlessCancelledToken] finallyDo:doneHandler];
    }
    
    return [resultSources map:^(TOCFutureSource* source) { return source.future; }];
}

-(TOCFuture*) asyncRaceAsynchronousResultUntilCancelledOperationsUntil:(TOCCancelToken*)untilCancelledToken {
    NSArray* starters = [self copy]; // remove volatility (i.e. ensure not externally mutable)
    require(starters.count > 0);
    require([starters allItemsAreKindOfClass:NSClassFromString(@"NSBlock")]);

    return [Racer asyncRace:starters until:untilCancelledToken];
}

@end
