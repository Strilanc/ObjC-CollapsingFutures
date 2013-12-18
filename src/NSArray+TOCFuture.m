#import "NSArray+TOCFuture.h"
#import "TOCFuture+MoreContinuations.h"
#import "TOCInternal.h"
#include <libkern/OSAtomic.h>

@implementation NSArray (TOCFuture)

-(TOCFuture*) toc_finallyAll {
    return [self toc_finallyAllUnless:nil];
}

-(TOCFuture*) toc_finallyAllUnless:(TOCCancelToken*)unlessCancelledToken {
    NSArray* futures = [self copy]; // remove volatility (i.e. ensure not externally mutable)
    TOCInternal_need([futures allItemsAreKindOfClass:[TOCFuture class]]);
    
    TOCFutureSource* resultSource = [TOCFutureSource new];
    
    TOCInternal_need(futures.count < INT_MAX);
    __block int remaining = (int)futures.count + 1;
    TOCCancelHandler doneHandler = ^() {
        if (OSAtomicDecrement32(&remaining) > 0) return;
        [resultSource trySetResult:futures];
    };
    
    for (TOCFuture* item in futures) {
        [item.cancelledOnCompletionToken whenCancelledDo:doneHandler
                                                  unless:unlessCancelledToken];
    }
    
    doneHandler();
    
    [unlessCancelledToken whenCancelledDo:^{ [resultSource trySetFailedWithCancel]; }
                                   unless:resultSource.future.cancelledOnCompletionToken];
    
    return resultSource.future;
}

-(TOCFuture*) toc_thenAll {
    return [self toc_thenAllUnless:nil];
}

-(TOCFuture*) toc_thenAllUnless:(TOCCancelToken*)unlessCancelledToken {
    return [[self toc_finallyAllUnless:unlessCancelledToken] then:^id(NSArray* completedFutures) {
        NSMutableArray* results = [NSMutableArray array];
        for (TOCFuture* item in completedFutures) {
            if (item.hasFailed) return [TOCFuture futureWithFailure:completedFutures];
            [results addObject:item.forceGetResult];
        }
        return results;
    }];
}

-(NSArray*) toc_orderedByCompletion {
    return [self toc_orderedByCompletionUnless:nil];
}

-(NSArray*) toc_orderedByCompletionUnless:(TOCCancelToken*)unlessCancelledToken {
    NSArray* futures = [self copy]; // remove volatility (i.e. ensure not externally mutable)
    TOCInternal_need([futures allItemsAreKindOfClass:[TOCFuture class]]);
    
    NSMutableArray* resultSources = [NSMutableArray array];
    
    TOCInternal_need(futures.count <= INT_MAX);
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

-(TOCFuture*) toc_raceForWinnerLastingUntil:(TOCCancelToken*)untilCancelledToken {
    NSArray* starters = [self copy]; // remove volatility (i.e. ensure not externally mutable)
    TOCInternal_need(starters.count > 0);
    TOCInternal_need([starters allItemsAreKindOfClass:NSClassFromString(@"NSBlock")]);
    
    return [TOCInternal_Racer asyncRace:starters until:untilCancelledToken];
}

@end
