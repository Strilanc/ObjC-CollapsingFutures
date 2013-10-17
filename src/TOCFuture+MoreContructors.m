#import "TOCFuture+MoreContructors.h"
#import "TOCFuture+MoreContinuations.h"
#import "TOCInternal.h"
#import "TOCTimeout.h"
#import "Array+TOCFuture.h"

@implementation TOCFuture (MoreConstructors)

+(TOCFuture*) futureWithResultFromOperation:(id (^)(void))operation
                          dispatchedOnQueue:(dispatch_queue_t)queue {
    require(operation != nil);
    
    TOCFutureSource* resultSource = [TOCFutureSource new];
    
    dispatch_async(queue, ^{ [resultSource forceSetResult:operation()]; });
    
    return resultSource.future;
}
+(TOCFuture*) futureWithResultFromOperation:(id(^)(void))operation
                            invokedOnThread:(NSThread*)thread {
    require(operation != nil);
    require(thread != nil);
    
    TOCFutureSource* resultSource = [TOCFutureSource new];
    
    [VoidBlock performBlock:^{ [resultSource forceSetResult:operation()]; }
                   onThread:thread];
    
    return resultSource.future;
}

+(TOCFuture*) futureWithResult:(id)resultValue
                    afterDelay:(NSTimeInterval)delayInSeconds {
    return [self futureWithResult:resultValue
                       afterDelay:delayInSeconds
                           unless:nil];
}
+(TOCFuture*) futureWithResult:(id)resultValue
                    afterDelay:(NSTimeInterval)delayInSeconds
                        unless:(TOCCancelToken*)unlessCancelledToken {
    require(delayInSeconds >= 0);
    require(!isnan(delayInSeconds));
    
    if (delayInSeconds == 0) return [TOCFuture futureWithResult:resultValue];
    
    TOCFutureSource* resultSource = [TOCFutureSource new];
    if (delayInSeconds == INFINITY) return resultSource.future;
    
    VoidBlock* target = [VoidBlock voidBlock:^{
        [resultSource trySetResult:resultValue];
    }];
    NSTimer* timer = [NSTimer timerWithTimeInterval:delayInSeconds
                                             target:target
                                           selector:[target runSelector]
                                           userInfo:nil
                                            repeats:NO];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
    
    [unlessCancelledToken whenCancelledDo:^{
        [timer invalidate];
        [resultSource trySetFailedWithCancel];
    } unless:resultSource.future.cancelledOnCompletionToken];
    
    return resultSource.future;
}

+(TOCFuture*) futureWithResultFromAsyncOperationWithResultLastingUntilCancelled:(TOCAsyncOperationWithResultLastingUntilCancelled)asyncOperationWithResultLastingUntilCancelled
                                                           withOperationTimeout:(NSTimeInterval)timeoutPeriodInSeconds
                                                                          until:(TOCCancelToken*)untilCancelledToken {
    require(asyncOperationWithResultLastingUntilCancelled != nil);
    require(timeoutPeriodInSeconds >= 0);
    require(!isnan(timeoutPeriodInSeconds));

    if (timeoutPeriodInSeconds == 0) {
        return [TOCFuture futureWithFailure:[TOCTimeout new]];
    }
    if (timeoutPeriodInSeconds == INFINITY) {
        return asyncOperationWithResultLastingUntilCancelled(untilCancelledToken);
    }
    
    TOCAsyncOperationWithResultLastingUntilCancelled timeoutOperation = ^(TOCCancelToken* internalUntilCancelledToken) {
        return [TOCFuture futureWithResult:[TOCFuture futureWithFailure:[TOCTimeout new]]
                                afterDelay:timeoutPeriodInSeconds
                                    unless:internalUntilCancelledToken];
    };
    
    NSArray* racingOperations = @[asyncOperationWithResultLastingUntilCancelled, timeoutOperation];
    return [racingOperations asyncRaceOperationsWithWinnerLastingUntil:untilCancelledToken];
}

+(TOCFuture*) futureWithResultFromAsyncOperation:(TOCAsyncCancellableOperation)asyncCancellableOperation
                                     withTimeout:(NSTimeInterval)timeoutPeriodInSeconds
                                          unless:(TOCCancelToken*)unlessCancelledToken {
    require(asyncCancellableOperation != nil);
    require(timeoutPeriodInSeconds >= 0);
    require(!isnan(timeoutPeriodInSeconds));

    if (timeoutPeriodInSeconds == 0) {
        return [TOCFuture futureWithFailure:[TOCTimeout new]];
    }
    if (timeoutPeriodInSeconds == INFINITY) {
        return asyncCancellableOperation(unlessCancelledToken);
    }
    
    // start the timeout countdown, making sure it cancels if the caller cancels
    TOCFuture* futureTimeout = [TOCFuture futureWithResult:nil
                                                afterDelay:timeoutPeriodInSeconds
                                                    unless:unlessCancelledToken];

    // start the operation, ensuring it cancels if the timeout finishes or is cancelled
    TOCFuture* futureOperationResult = asyncCancellableOperation(futureTimeout.cancelledOnCompletionToken);

    // wait for the operation to finish or be cancelled or timeout
    return [futureOperationResult finally:^(TOCFuture* completedOperationResult) {
        // detect when cancellation was due to timeout, and report appropriately
        bool wasCancelled = completedOperationResult.hasFailedWithCancel;
        bool wasNotCancelledExternally = !unlessCancelledToken.isAlreadyCancelled;
        bool wasTimeout = wasCancelled && wasNotCancelledExternally;
        if (wasTimeout) {
            return [TOCFuture futureWithFailure:[TOCTimeout new]];
        }
        
        return completedOperationResult;
    }];
}

+(TOCFuture*) futureWithResultFromAsyncOperation:(TOCAsyncCancellableOperation)asyncCancellableOperation
                                     withTimeout:(NSTimeInterval)timeoutPeriodInSeconds {
    require(asyncCancellableOperation != nil);
    require(timeoutPeriodInSeconds >= 0);
    require(!isnan(timeoutPeriodInSeconds));

    return [self futureWithResultFromAsyncOperation:asyncCancellableOperation
                                        withTimeout:timeoutPeriodInSeconds
                                             unless:nil];
}

@end
