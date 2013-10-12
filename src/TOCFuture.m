#import "TOCFuture.h"
#import "TOCCommonDefs.h"

#define FUTURE_STATE_INCOMPLETE 0
#define FUTURE_STATE_SUCCEEDED 1
#define FUTURE_STATE_FAILED 2
#define FUTURE_STATE_ETERNAL 3

@implementation TOCFuture {
@private NSMutableArray* completionHandlers;
@private int state;
@private id value;
@private bool hasBeenSet;
}

+(TOCFuture *)futureWithResult:(id)resultValue {
    if ([resultValue isKindOfClass:[TOCFuture class]]) {
        return resultValue;
    }
    
    TOCFuture *instance = [TOCFuture new];
    instance->state = FUTURE_STATE_SUCCEEDED;
    instance->value = resultValue;
    return instance;
}
+(TOCFuture *)futureWithFailure:(id)failureValue {
    TOCFuture *instance = [TOCFuture new];
    instance->state = FUTURE_STATE_FAILED;
    instance->value = failureValue;
    return instance;
}

+(TOCFuture*) __ForSource__completableFuture {
    TOCFuture *future = [TOCFuture new];
    future->completionHandlers = [NSMutableArray array];
    return future;
}
-(bool) __ForSource__trySetResult:(id)finalResult {
    // automatic flattening
    if ([finalResult isKindOfClass:[TOCFuture class]]) {
        return [self __trySetWithUnwrap:finalResult];
    }

    return [self __trySet:finalResult
                    state:FUTURE_STATE_SUCCEEDED
               isUnwiring:false];
}
-(bool) __ForSource__trySetFailure:(id)finalFailure {
    return [self __trySet:finalFailure
                    state:FUTURE_STATE_FAILED
               isUnwiring:false];
}
-(bool) __ForSource__trySetEternal {
    return [self __trySet:nil
                    state:FUTURE_STATE_ETERNAL
               isUnwiring:false];
}

-(bool) __trySet:(id)finalValue
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
    
    if (state == FUTURE_STATE_ETERNAL) return true;
    for (TOCFutureFinallyHandler handler in completionHandlersAtCompletion) {
        handler(self);
    }
    return true;
}
-(bool) __trySetWithUnwrap:(TOCFuture*)futureFinalResult {
    require(futureFinalResult != nil);
    
    @synchronized(self) {
        if (hasBeenSet) return false;
        hasBeenSet = true;
    }
    
    [futureFinalResult finallyDo:^(TOCFuture *completed) {
        [self __trySet:completed->value
                 state:completed->state
            isUnwiring:true];
    }];
    
    return true;
}


-(bool)isIncomplete {
    @synchronized(self) {
        return state == FUTURE_STATE_INCOMPLETE || state == FUTURE_STATE_ETERNAL;
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
    require([self hasResult]);
    return value;
}
-(id)forceGetFailure {
    require([self hasFailed]);
    return value;
}

-(void)addOrRunCompletionhandler:(TOCFutureFinallyHandler)completionHandler {
    @synchronized(self) {
        if (state == FUTURE_STATE_ETERNAL) return;
        if (state == FUTURE_STATE_INCOMPLETE) {
            [completionHandlers addObject:[completionHandler copy]];
            return;
        }
    }
    
    completionHandler(self);
}

-(void)finallyDo:(TOCFutureFinallyHandler)completionHandler {
    require(completionHandler != nil);
    
    [self addOrRunCompletionhandler:completionHandler];
}
-(void)thenDo:(TOCFutureThenHandler)resultHandler {
    require(resultHandler != nil);
    
    TOCFutureThenHandler resultHandlerCopy = [resultHandler copy];

    [self addOrRunCompletionhandler:^(TOCFuture *completed) {
        if (completed->state == FUTURE_STATE_SUCCEEDED) {
            resultHandlerCopy(completed->value);
        }
    }];
}
-(void)catchDo:(TOCFutureCatchHandler)failureHandler {
    require(failureHandler != nil);
    
    TOCFutureCatchHandler failureHandlerCopy = [failureHandler copy];
    
    [self addOrRunCompletionhandler:^(TOCFuture *completed) {
        if (completed->state == FUTURE_STATE_FAILED) {
            failureHandlerCopy(completed->value);
        }
    }];
}

-(TOCFuture *)finally:(TOCFutureFinallyContinuation)completionContinuation {
    require(completionContinuation != nil);
    
    TOCFutureFinallyContinuation completionContinuationCopy = [completionContinuation copy];
    TOCFutureSource* resultSource = [TOCFutureSource new];
    
    [self addOrRunCompletionhandler:^(TOCFuture *completed) {
        [resultSource trySetResult:completionContinuationCopy(completed)];
    }];
    return resultSource.future;
}
-(TOCFuture *)then:(TOCFutureThenContinuation)resultContinuation {
    require(resultContinuation != nil);

    TOCFutureFinallyContinuation resultContinuationCopy = [resultContinuation copy];
    TOCFutureSource* resultSource = [TOCFutureSource new];

    [self addOrRunCompletionhandler:^(TOCFuture *completed) {
        if (completed->state == FUTURE_STATE_SUCCEEDED) {
            [resultSource trySetResult:resultContinuationCopy(completed->value)];
        } else {
            [resultSource trySetFailure:completed->value];
        }
    }];
    return resultSource.future;
}
-(TOCFuture *)catch:(TOCFutureCatchContinuation)failureContinuation {
    require(failureContinuation != nil);
    
    TOCFutureFinallyContinuation failureContinuationCopy = [failureContinuation copy];
    TOCFutureSource* resultSource = [TOCFutureSource new];
    
    [self addOrRunCompletionhandler:^(TOCFuture *completed) {
        if (completed->state == FUTURE_STATE_SUCCEEDED) {
            [resultSource trySetResult:completed->value];
        } else {
            [resultSource trySetResult:failureContinuationCopy(completed->value)];
        }
    }];
    
    return resultSource.future;
}

-(NSString*) description {
    @synchronized(self) {
        if (state == FUTURE_STATE_SUCCEEDED) return [NSString stringWithFormat:@"Future with Result: %@", value];
        if (state == FUTURE_STATE_FAILED) return [NSString stringWithFormat:@"Future with Failure: %@", value];
        if (state == FUTURE_STATE_ETERNAL) return @"Incomplete Future [Eternal]";
        if (hasBeenSet && state == FUTURE_STATE_INCOMPLETE) return @"Incomplete Future [Set]";
        return @"Incomplete Future";
    }
}

@end

@implementation TOCFutureSource

@synthesize future;

-(TOCFutureSource*) init {
    self = [super init];
    if (self) {
        self->future = [TOCFuture __ForSource__completableFuture];
    }
    return self;
}

-(void) dealloc {
    [future __ForSource__trySetEternal];
}
-(bool) trySetResult:(id)finalResult {
    return [future __ForSource__trySetResult:finalResult];
}
-(bool) trySetFailure:(id)finalFailure {
    return [future __ForSource__trySetFailure:finalFailure];
}

-(void) forceSetResult:(id)finalResult {
    require([self trySetResult:finalResult]);
}
-(void) forceSetFailure:(id)finalFailure {
    require([self trySetFailure:finalFailure]);
}

-(NSString*) description {
    return [NSString stringWithFormat:@"Future Source: %@", future];
}

@end
