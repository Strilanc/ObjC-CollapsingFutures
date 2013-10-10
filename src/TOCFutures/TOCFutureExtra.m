#import "TOCFutureExtra.h"

#define require(expr) \
    if (!(expr)) \
        @throw([NSException exceptionWithName:NSInvalidArgumentException \
                                       reason:[NSString stringWithFormat:@"!require(%@)", (@#expr)] \
                                     userInfo:nil])

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

+(NSArray*) orderedByCompletion:(NSArray*)futures {
    require(futures != nil);
    futures = [futures copy]; // remove volatility (i.e. ensure not externally mutable)
    for (TOCFuture* item in futures) {
        require([item isKindOfClass:[TOCFuture class]]);
    }
    
    NSMutableArray* result = [NSMutableArray array];
    
    __block NSUInteger completedCount = 0;
    NSObject* lock = [NSObject new];
    TOCFutureFinallyHandler doneHandler = ^(TOCFuture *completed) {
        NSUInteger i;
        @synchronized(lock) {
            i = completedCount++;
        }
        [[result objectAtIndex:i] trySetResult:completed];
    };
    
    for (TOCFuture* item in futures) {
        [result addObject:[TOCFutureSource new]];
    }
    for (TOCFuture* item in futures) {
        [item finallyDo:doneHandler];
    }
    
    return [result copy];
}

+(TOCFuture*) whenAll:(NSArray*)futures {
    require(futures != nil);
    futures = [futures copy]; // remove volatility (i.e. ensure not externally mutable)
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
        
        [resultSource trySetFailure:futures];
    };
    
    for (TOCFuture* item in futures) {
        [item finallyDo:doneHandler];
    }
    
    doneHandler(nil);
    
    return resultSource;
}

@end
