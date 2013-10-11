#import "TOCFutureExtra.h"
#import "TOCCommonDefs.h"

@interface VoidBlock : NSObject { @public void (^block)(void); }
+(VoidBlock*) voidBlock:(void(^)(void))block;
-(void)run;
-(SEL)runSelector;
@end
@implementation VoidBlock
+(VoidBlock*) voidBlock:(void(^)(void))block {
    VoidBlock* b = [VoidBlock new];
    b->block = [block copy];
    return b;
}
-(void)run {
    block();
}
-(SEL)runSelector { return @selector(run); }
@end

@implementation TOCFuture (TOCFutureExtra)

+(TOCFuture*) futureWithResultFromOperation:(id (^)(void))operation
                          dispatchedOnQueue:(dispatch_queue_t)queue {
    require(operation != nil);
    
    TOCFutureSource* resultSource = [TOCFutureSource new];
    
    dispatch_async(queue, ^{ [resultSource trySetResult:operation()]; });
    
    return resultSource;
}
+(TOCFuture*) futureWithResultFromOperation:(id(^)(void))operation
                            invokedOnThread:(NSThread*)thread {
    require(operation != nil);
    require(thread != nil);
    
    TOCFutureSource* resultSource = [TOCFutureSource new];
    
    VoidBlock* block = [VoidBlock voidBlock:^{
        [resultSource trySetResult:operation()];
    }];
    [block performSelector:[block runSelector]
                  onThread:thread
                withObject:block
             waitUntilDone:NO];
    
    return resultSource;
}

+(TOCFuture*) futureWithResult:(id)resultValue
                    afterDelay:(NSTimeInterval)delay {
    require(delay >= 0);
    
    if (delay == 0) return [TOCFuture futureWithResult:resultValue];
    
    TOCFutureSource* resultSource = [TOCFutureSource new];
    if (delay == INFINITY) return resultSource;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [resultSource trySetResult:resultValue];
    });
    
    return resultSource;
}

@end
