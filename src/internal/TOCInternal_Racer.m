#import "TOCInternal.h"
#import "TOCFuture+MoreContinuations.h"
#include <libkern/OSAtomic.h>

@implementation TOCInternal_Racer

@synthesize canceller, futureResult;

+(TOCInternal_Racer*) racerStartedFrom:(TOCUntilOperation)starter
                                 until:(TOCCancelToken*)untilCancelledToken {
    TOCInternal_need(starter != nil);
    
    TOCInternal_Racer* racer = [TOCInternal_Racer new];
    
    racer->canceller = [TOCCancelTokenSource cancelTokenSourceUntil:untilCancelledToken];
    racer->futureResult = starter(racer.canceller.token);
    
    return racer;
}

+(TOCFuture*) asyncRace:(NSArray*)starters
                  until:(TOCCancelToken*)untilCancelledToken {
    
    // start all operations (as racers that can be individually cancelled after-the-fact)
    NSArray* racers = [starters map:^(id starter) { return [TOCInternal_Racer racerStartedFrom:starter
                                                                                         until:untilCancelledToken]; }];
    
    // make a podium for the winner, assuming the race isn't called off
    TOCFutureSource* futureWinningRacerSource = [TOCFutureSource futureSourceUntil:untilCancelledToken];
    
    // tell each racer how to get on the podium (or how to be a failure)
    __block int failedRacerCount = 0;
    TOCInternal_need(racers.count <= INT_MAX);
    for (TOCInternal_Racer* racer in racers) {
        [racer.futureResult finallyDo:^(TOCFuture *completed) {
            if (completed.hasResult) {
                // winner?
                [futureWinningRacerSource trySetResult:racer];
            } else if (OSAtomicIncrement32(&failedRacerCount) == (int)racers.count) {
                // prefer to fail with a cancellation over failing with a list of cancellations
                if (untilCancelledToken.isAlreadyCancelled) return;
                
                // everyone is a failure, thus so are we
                NSArray* allFailures = [racers map:^(TOCInternal_Racer* r) { return r.futureResult.forceGetFailure; }];
                [futureWinningRacerSource trySetFailure:allFailures];
            }
        } unless:untilCancelledToken];
    }
    
    // once there's a winner, cancel the other racers
    [futureWinningRacerSource.future thenDo:^(TOCInternal_Racer* winningRacer) {
        for (TOCInternal_Racer* racer in racers) {
            if (racer != winningRacer) {
                [racer.canceller cancel];
            }
        }
    }];
    
    // get the winning racer's result
    TOCFuture* futureWinnerResult = [futureWinningRacerSource.future then:^id(TOCInternal_Racer* winningRacer) { return winningRacer.futureResult; }];
    
    return futureWinnerResult;
}

@end
