#import "FutureExtra.h"

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

@implementation Future (FutureExtra)

+(Future*) futureWithResultFromOperation:(id (^)(void))operation
                       dispatchedOnQueue:(dispatch_queue_t)queue {
    require(operation != nil);
    
    FutureSource* resultSource = [FutureSource new];
    
    dispatch_async(queue, ^{ [resultSource trySetResult:operation()]; });
    
    return resultSource;
}
+(Future*) futureWithResultFromOperation:(id(^)(void))operation
                         invokedOnThread:(NSThread*)thread {
    require(operation != nil);
    require(thread != nil);

    FutureSource* resultSource = [FutureSource new];

    VoidBlock* block = [VoidBlock voidBlock:^{
        [resultSource trySetResult:operation()];
    }];
    [block performSelector:[block runSelector]
                  onThread:thread
                withObject:block
             waitUntilDone:NO];
    
    return resultSource;
}

+(Future*) futureWithResult:(id)resultValue
                 afterDelay:(NSTimeInterval)delay {
    require(delay >= 0);
    
    if (delay == 0) return [Future futureWithResult:resultValue];
    
    FutureSource* resultSource = [FutureSource new];
    if (delay == INFINITY) return resultSource;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [resultSource trySetResult:resultValue];
    });
    
    return resultSource;
}

+(NSArray*) orderedByCompletion:(NSArray*)futures {
    require(futures != nil);
    for (Future* item in futures) {
        require([item isKindOfClass:[Future class]]);
    }
    
    NSMutableArray* result = [NSMutableArray array];
    
    __block NSUInteger completedCount = 0;
    NSObject* lock = [NSObject new];
    FutureCompletionHandler doneHandler = ^(Future *completed) {
        NSUInteger i;
        @synchronized(lock) {
            i = completedCount++;
        }
        [[result objectAtIndex:i] trySetResult:completed];
    };
    
    for (Future* item in futures) {
        [result addObject:[FutureSource new]];
    }
    for (Future* item in futures) {
        [item finallyDo:doneHandler];
    }
    
    return [result copy];
}

+(Future*) whenAll:(NSArray*)futures {
    require(futures != nil);
    futures = [futures copy]; // remove volatility
    for (Future* item in futures) {
        require([item isKindOfClass:[Future class]]);
    }
    
    FutureSource* resultSource = [FutureSource new];
    
    __block NSUInteger remaining = [futures count] + 1;
    NSObject* lock = [NSObject new];
    FutureCompletionHandler doneHandler = ^(Future *completed) {
        @synchronized(lock) {
            remaining--;
            if (remaining > 0) return;
        }
        
        [resultSource trySetFailure:futures];
    };
    
    for (Future* item in futures) {
        [item finallyDo:doneHandler];
    }
    
    doneHandler(nil);
    
    return resultSource;
}

@end
