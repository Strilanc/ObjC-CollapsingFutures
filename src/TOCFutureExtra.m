#import "TOCFutureExtra.h"
#import "Internal.h"

@implementation TOCFuture (TOCFutureExtra)

-(bool)hasFailedWithCancel {
    return self.hasFailed && [self.forceGetFailure isKindOfClass:[TOCCancelToken class]];
}

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
                    afterDelay:(NSTimeInterval)delay {
    return [self futureWithResult:resultValue
                       afterDelay:delay
                           unless:nil];
}
+(TOCFuture*) futureWithResult:(id)resultValue
                    afterDelay:(NSTimeInterval)delay
                        unless:(TOCCancelToken*)unlessCancelledToken {
    require(delay >= 0);
    
    if (delay == 0) return [TOCFuture futureWithResult:resultValue];
    
    TOCFutureSource* resultSource = [TOCFutureSource new];
    if (delay == INFINITY) return resultSource.future;
    
    VoidBlock* target = [VoidBlock voidBlock:^{
        [resultSource trySetResult:resultValue];
    }];
    NSTimer* timer = [NSTimer timerWithTimeInterval:delay
                                             target:target
                                           selector:[target runSelector]
                                           userInfo:nil
                                            repeats:NO];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
    
    [unlessCancelledToken whenCancelledDo:^{
        [timer invalidate];
        [resultSource trySetFailure:unlessCancelledToken];
    }];
    
    return resultSource.future;
}

@end
