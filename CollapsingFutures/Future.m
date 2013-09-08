#import "Future.h"

#define FUTURE_STATE_INCOMPLETE 0
#define FUTURE_STATE_SUCCEEDED 1
#define FUTURE_STATE_FAILED -1
#define require(expr) \
    if (!(expr)) \
        @throw([NSException exceptionWithName:NSInvalidArgumentException \
                                       reason:[NSString stringWithFormat:@"!require(%@)", (@#expr)] \
                                     userInfo:nil])

@implementation Future

+(Future *)futureWithResult:(id)resultValue {
    if ([resultValue isKindOfClass:[Future class]]) {
        return resultValue;
    }
    
    Future *instance = [[Future alloc] init];
    instance->state = FUTURE_STATE_SUCCEEDED;
    instance->value = resultValue;
    return instance;
}
+(Future *)futureWithFailure:(id)failureValue {
    Future *instance = [[Future alloc] init];
    instance->state = FUTURE_STATE_FAILED;
    instance->value = failureValue;
    return instance;
}

-(bool)isIncomplete {
    @synchronized(self) {
        return state == FUTURE_STATE_INCOMPLETE;
    }
}
-(bool)hasResult {
    @synchronized(self) {
        return state == FUTURE_STATE_SUCCEEDED;
    }
}
-(bool)hasFailed {
    @synchronized(self) {
        return state == FUTURE_STATE_FAILED;
    }
}
-(id)forceGetResult {
    @synchronized(self) {
        require(state == FUTURE_STATE_SUCCEEDED);
    }
    return value;
}
-(id)forceGetFailure {
    @synchronized(self) {
        require(state == FUTURE_STATE_FAILED);
    }
    return value;
}

-(void)addOrRunCompletionhandler:(FutureCompletionHandler)completionHandler {
    @synchronized(self) {
        if (state == FUTURE_STATE_INCOMPLETE) {
            [completionHandlers addObject:[completionHandler copy]];
            return;
        }
    }
    
    completionHandler(self);
}

-(void)finallyDo:(FutureCompletionHandler)completionHandler {
    require(completionHandler != nil);
    
    [self addOrRunCompletionhandler:completionHandler];
}
-(void)thenDo:(FutureResultHandler)resultHandler {
    require(resultHandler != nil);
    
    FutureResultHandler resultHandlerCopy = [resultHandler copy];

    [self addOrRunCompletionhandler:^(Future *completed) {
        if (completed->state == FUTURE_STATE_SUCCEEDED) {
            resultHandlerCopy(completed->value);
        }
    }];
}
-(void)catchDo:(FutureFailureHandler)failureHandler {
    require(failureHandler != nil);
    
    FutureFailureHandler failureHandlerCopy = [failureHandler copy];
    
    [self addOrRunCompletionhandler:^(Future *completed) {
        if (completed->state == FUTURE_STATE_FAILED) {
            failureHandlerCopy(completed->value);
        }
    }];
}

-(Future *)finally:(FutureCompletionContinuation)completionContinuation {
    require(completionContinuation != nil);
    
    FutureCompletionContinuation completionContinuationCopy = [completionContinuation copy];
    FutureSource* resultSource = [FutureSource new];
    
    [self addOrRunCompletionhandler:^(Future *completed) {
        [resultSource trySetResult:completionContinuationCopy(completed)];
    }];
    return resultSource;
}
-(Future *)then:(FutureResultContinuation)resultContinuation {
    require(resultContinuation != nil);

    FutureCompletionContinuation resultContinuationCopy = [resultContinuation copy];
    FutureSource* resultSource = [FutureSource new];

    [self addOrRunCompletionhandler:^(Future *completed) {
        if (completed->state == FUTURE_STATE_SUCCEEDED) {
            [resultSource trySetResult:resultContinuationCopy(completed->value)];
        } else {
            [resultSource trySetFailure:completed->value];
        }
    }];
    return resultSource;
}
-(Future *)catch:(FutureFailureContinuation)failureContinuation {
    require(failureContinuation != nil);
    
    FutureCompletionContinuation failureContinuationCopy = [failureContinuation copy];
    FutureSource* resultSource = [FutureSource new];
    
    [self addOrRunCompletionhandler:^(Future *completed) {
        if (completed->state == FUTURE_STATE_SUCCEEDED) {
            [resultSource trySetResult:completed->value];
        } else {
            [resultSource trySetResult:failureContinuationCopy(completed->value)];
        }
    }];
    
    return resultSource;
}

-(NSString*) description {
    @synchronized(self) {
        if (state == FUTURE_STATE_SUCCEEDED) return [NSString stringWithFormat:@"Future with result: %@", value];
        if (state == FUTURE_STATE_FAILED) return [NSString stringWithFormat:@"Future with failure: %@", value];
        return @"Incomplete Future";
    }
}

@end

@implementation FutureSource

-(FutureSource*) init {
    self = [super init];
    if (self) {
        self->completionHandlers = [NSMutableArray array];
    }
    return self;
}

-(bool) trySet:(id)finalValue
         state:(int)finalState
    isUnwiring:(bool)unwiring {
    
    NSArray* completionHandlersAtCompletion;
    @synchronized(self) {
        if (hasBeenSet && !unwiring) return false;
        
        completionHandlersAtCompletion = completionHandlers;
        completionHandlers = nil;
        hasBeenSet = true;
        value = finalValue;
        state = finalState;
    }
    
    for (FutureCompletionHandler handler in completionHandlersAtCompletion) {
        handler(self);
    }
    return true;
}

-(bool) trySetWithUnwrap:(Future*)futureFinalResult {
    require(futureFinalResult != nil);
    
    @synchronized(self) {
        if (hasBeenSet) return false;
        hasBeenSet = true;
    }
    
    [futureFinalResult finallyDo:^(Future *completed) {
        [self trySet:completed->value
               state:completed->state
          isUnwiring:true];
    }];
    
    return true;
}

-(bool) trySetResult:(id)finalResult {
    if ([finalResult isKindOfClass:[Future class]]) {
        return [self trySetWithUnwrap:finalResult];
    }
    
    return [self trySet:finalResult
                  state:FUTURE_STATE_SUCCEEDED
             isUnwiring:false];
}
-(bool) trySetFailure:(id)finalFailure {
    return [self trySet:finalFailure
                  state:FUTURE_STATE_FAILED
             isUnwiring:false];
}

-(NSString*) description {
    @synchronized(self) {
        if (hasBeenSet && state == FUTURE_STATE_INCOMPLETE) return @"Incomplete Future [Set]";
        return [super description];
    }
}

@end
