#import "TOCFutureAndSource.h"
#import "Internal.h"

@implementation TOCFuture {
@private id value;
@private bool ifDoneHasSucceeded;
@private bool hasBeenSet;
@private TOCCancelToken* completionToken;
}

+(TOCFuture *)futureWithResult:(id)resultValue {
    if ([resultValue isKindOfClass:[TOCFuture class]]) {
        return resultValue;
    }
    
    TOCFuture *future = [TOCFuture new];
    future->completionToken = [TOCCancelToken cancelledToken];
    future->ifDoneHasSucceeded = true;
    future->value = resultValue;
    return future;
}
+(TOCFuture *)futureWithFailure:(id)failureValue {
    TOCFuture *future = [TOCFuture new];
    future->completionToken = [TOCCancelToken cancelledToken];
    future->ifDoneHasSucceeded = false;
    future->value = failureValue;
    return future;
}

+(TOCFuture*) __ForSource__completableFutureWithCompletionToken:(TOCCancelToken*)completionToken {
    TOCFuture* future = [TOCFuture new];
    future->completionToken = completionToken;
    return future;
}

-(bool) __ForSource__tryStartFutureSet {
    @synchronized(self) {
        if (hasBeenSet) return false;
        hasBeenSet = true;
    }
    return true;
}
-(void) __ForSource__forceFinishFutureSet:(TOCFuture*)finalValue {
    require(finalValue != nil);
    require([self __trySet:finalValue->value
                 succeeded:finalValue->ifDoneHasSucceeded
                isUnwiring:true]);
}
-(bool) __ForSource__trySet:(id)finalValue
                  succeeded:(bool)succeeded {
    return [self __trySet:finalValue
                succeeded:succeeded
               isUnwiring:false];
}
-(bool) __trySet:(id)finalValue
       succeeded:(bool)succeeded
      isUnwiring:(bool)unwiring {
    
    require(![finalValue isKindOfClass:[TOCFuture class]]);
    
    @synchronized(self) {
        if (hasBeenSet && !unwiring) return false;
        hasBeenSet = true;
        value = finalValue;
        ifDoneHasSucceeded = succeeded;
    }
    return true;
}


-(TOCCancelToken*) cancelledOnCompletionToken {
    return completionToken;
}

-(bool)isIncomplete {
    return ![completionToken isAlreadyCancelled];
}
-(bool)hasResult {
    return [completionToken isAlreadyCancelled] && ifDoneHasSucceeded;
}
-(bool)hasFailed {
    return [completionToken isAlreadyCancelled] && !ifDoneHasSucceeded;
}
-(id)forceGetResult {
    require([self hasResult]);
    return value;
}
-(id)forceGetFailure {
    require([self hasFailed]);
    return value;
}

-(void)finallyDo:(TOCFutureFinallyHandler)completionHandler
          unless:(TOCCancelToken *)unlessCancelledToken {
    require(completionHandler != nil);

    __unsafe_unretained TOCFuture* weakSelf = self;
    [completionToken whenCancelledDo:^{ completionHandler(weakSelf); }
                              unless:unlessCancelledToken];
}

-(void)thenDo:(TOCFutureThenHandler)resultHandler
       unless:(TOCCancelToken *)unlessCancelledToken {
    require(resultHandler != nil);
    
    [self finallyDo:^(TOCFuture *completed) {
        if (completed->ifDoneHasSucceeded) {
            resultHandler(completed->value);
        }
    } unless:unlessCancelledToken];
}

-(void)catchDo:(TOCFutureCatchHandler)failureHandler
        unless:(TOCCancelToken *)unlessCancelledToken {
    require(failureHandler != nil);
    
    [self finallyDo:^(TOCFuture *completed) {
        if (!completed->ifDoneHasSucceeded) {
            failureHandler(completed->value);
        }
    } unless:unlessCancelledToken];
}

-(TOCFuture *)finally:(TOCFutureFinallyContinuation)completionContinuation
               unless:(TOCCancelToken *)unlessCancelledToken {
    require(completionContinuation != nil);
    
    TOCFutureSource* resultSource = [TOCFutureSource new];
    
    [self finallyDo:^(TOCFuture *completed) {
        [resultSource trySetResult:completionContinuation(completed)];
    } unless:unlessCancelledToken];
    [unlessCancelledToken whenCancelledDo:^{
        [resultSource trySetFailure:unlessCancelledToken];
    } unless:resultSource.future->completionToken];
    
    return resultSource.future;
}

-(TOCFuture *)then:(TOCFutureThenContinuation)resultContinuation unless:(TOCCancelToken *)unlessCancelledToken {
    require(resultContinuation != nil);
    
    return [self finally:^id(TOCFuture *completed) {
        if (completed->ifDoneHasSucceeded) {
            return resultContinuation(completed->value);
        } else {
            return completed;;
        }
    } unless:unlessCancelledToken];
}

-(TOCFuture *)catch:(TOCFutureCatchContinuation)failureContinuation
             unless:(TOCCancelToken *)unlessCancelledToken {
    require(failureContinuation != nil);
    
    return [self finally:^(TOCFuture *completed) {
        if (completed->ifDoneHasSucceeded) {
            return completed->value;
        } else {
            return failureContinuation(completed->value);
        }
    } unless:unlessCancelledToken];
}

-(NSString*) description {
    @synchronized(self) {
        bool isIncomplete = ![completionToken isAlreadyCancelled];
        bool isStuck = ![completionToken canStillBeCancelled];
        
        if (isIncomplete) {
            if (isStuck) return @"Incomplete Future [Eternal]";
            if (hasBeenSet) return @"Incomplete Future [Set]";
            return @"Incomplete Future";
        }
        return [NSString stringWithFormat:@"Future with %@: %@",
                ifDoneHasSucceeded ? @"Result" : @"Failure",
                value];
    }
}

@end

@implementation TOCFutureSource {
@private TOCCancelTokenSource* completionSource;
}

@synthesize future;

-(TOCFutureSource*) init {
    self = [super init];
    if (self) {
        self->completionSource = [TOCCancelTokenSource new];
        self->future = [TOCFuture __ForSource__completableFutureWithCompletionToken:self->completionSource.token];
    }
    return self;
}

-(bool) trySetResult:(id)finalResult {
    // automatic flattening
    if ([finalResult isKindOfClass:[TOCFuture class]]) {
        if (![future __ForSource__tryStartFutureSet]) return false;
        
        // optimize self-dependence into immortality
        if (finalResult == future) {
            completionSource = nil;
            return true;
        }
        
        [(TOCFuture*)finalResult finallyDo:^(TOCFuture *completed) {
            [future __ForSource__forceFinishFutureSet:completed];
            [completionSource cancel];
        } unless:nil];
        
        return true;
    }
    
    return [future __ForSource__trySet:finalResult succeeded:true] && [completionSource tryCancel];
}
-(bool) trySetFailure:(id)finalFailure {
    return [future __ForSource__trySet:finalFailure succeeded:false] && [completionSource tryCancel];
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
