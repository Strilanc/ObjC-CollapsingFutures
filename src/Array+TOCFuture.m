#import "Array+TOCFuture.h"
#import "TOCFuture+MoreContinuations.h"
#import "TOCInternal.h"
#include <libkern/OSAtomic.h>

@implementation NSArray (TOCFuture)

-(TOCFuture*) asyncFinallyAll {
    return [self asyncFinallyAllUnless:nil];
}

-(TOCFuture*) asyncFinallyAllUnless:(TOCCancelToken*)unlessCancelledToken {
    NSArray* futures = [self copy]; // remove volatility (i.e. ensure not externally mutable)
    require([futures allItemsAreKindOfClass:[TOCFuture class]]);
    
    TOCFutureSource* resultSource = [TOCFutureSource new];
    
    require(futures.count < INT_MAX);
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

-(TOCFuture*) asyncThenAll {
    return [self asyncThenAllUnless:nil];
}

-(TOCFuture*) asyncThenAllUnless:(TOCCancelToken*)unlessCancelledToken {
    return [[self asyncFinallyAllUnless:unlessCancelledToken] then:^id(NSArray* completedFutures) {
        NSMutableArray* results = [NSMutableArray array];
        for (TOCFuture* item in completedFutures) {
            if (item.hasFailed) return [TOCFuture futureWithFailure:completedFutures];
            [results addObject:item.forceGetResult];
        }
        return results;
    }];
}

-(NSArray*) asyncOrderedByCompletion {
    return [self asyncOrderedByCompletionUnless:nil];
}

-(NSArray*) asyncOrderedByCompletionUnless:(TOCCancelToken*)unlessCancelledToken {
    NSArray* futures = [self copy]; // remove volatility (i.e. ensure not externally mutable)
    require([futures allItemsAreKindOfClass:[TOCFuture class]]);
    
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

-(TOCFuture*) asyncRaceOperationsWithWinningResultLastingUntil:(TOCCancelToken*)untilCancelledToken {
    NSArray* starters = [self copy]; // remove volatility (i.e. ensure not externally mutable)
    require(starters.count > 0);
    require([starters allItemsAreKindOfClass:NSClassFromString(@"NSBlock")]);
    
    return [TOCInternal_Racer asyncRace:starters until:untilCancelledToken];
}

@end
