#import "TOCInternal_Racer.h"
#import "TOCInternal.h"
#import "TOCInternal_Array+Functional.h"
#import "TOCFuture+MoreContinuations.h"
#include <libkern/OSAtomic.h>

@implementation Racer

@synthesize canceller, futureResult;

+(Racer*) racerStartedFrom:(AsynchronousUntilCancelledOperationStarter)starter
                     until:(TOCCancelToken*)untilCancelledToken {
    require(starter != nil);
    
    Racer* racer = [Racer new];
    
    racer->canceller = [TOCCancelTokenSource new];
    [untilCancelledToken whenCancelledCancelSource:racer->canceller];
    racer->futureResult = starter(racer.canceller.token);
    
    return racer;
}

+(TOCFuture*) asyncRace:(NSArray*)starters
                  until:(TOCCancelToken*)untilCancelledToken {
    
    // start all operations (as racers that can be individually cancelled after-the-fact)
    NSArray* racers = [starters map:^(id starter) { return [Racer racerStartedFrom:starter
                                                                             until:untilCancelledToken]; }];
    
    // make a podium for the winner, assuming the race isn't called off
    TOCFutureSource* futureWinningRacerSource = [TOCFutureSource new];
    [untilCancelledToken whenCancelledTryCancelFutureSource:futureWinningRacerSource];
    
    // tell each racer how to get on the podium (or how to be a failure)
    __block int failedRacerCount = 0;
    require(racers.count <= INT_MAX);
    for (Racer* racer in racers) {
        [racer.futureResult finallyDo:^(TOCFuture *completed) {
            if (completed.hasResult) {
                // winner?
                [futureWinningRacerSource trySetResult:racer];
            } else if (OSAtomicIncrement32(&failedRacerCount) == (int)racers.count) {
                // prefer to fail with a cancellation over failing with a list of cancellations
                if (untilCancelledToken.isAlreadyCancelled) return;
                
                // everyone is a failure, thus so are we
                NSArray* allFailures = [racers map:^(Racer* r) { return r.futureResult.forceGetFailure; }];
                [futureWinningRacerSource trySetFailure:allFailures];
            }
        } unless:untilCancelledToken];
    }

    // once there's a winner, cancel the other racers
    [futureWinningRacerSource.future thenDo:^(Racer* winningRacer) {
        for (Racer* racer in racers) {
            if (racer != winningRacer) {
                [racer.canceller cancel];
            }
        }
    }];

    // get the winning racer's result
    TOCFuture* futureWinnerResult = [futureWinningRacerSource.future then:^id(Racer* winningRacer) { return winningRacer.futureResult; }];
    
    return futureWinnerResult;
}

@end
