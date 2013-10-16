#import "TOCFutureAndSource.h"
#import "Internal.h"

@implementation TOCFuture {
@private id _value;
@private bool _ifDoneHasSucceeded;
@private bool _hasBeenSet;
@private TOCCancelToken* _completionToken;
}

+(TOCFuture *)futureWithResult:(id)resultValue {
    if ([resultValue isKindOfClass:[TOCFuture class]]) {
        return resultValue;
    }
    
    TOCFuture *future = [TOCFuture new];
    future->_completionToken = [TOCCancelToken cancelledToken];
    future->_ifDoneHasSucceeded = true;
    future->_value = resultValue;
    return future;
}
+(TOCFuture *)futureWithFailure:(id)failureValue {
    TOCFuture *future = [TOCFuture new];
    future->_completionToken = [TOCCancelToken cancelledToken];
    future->_ifDoneHasSucceeded = false;
    future->_value = failureValue;
    return future;
}

+(TOCFuture*) __ForSource__completableFutureWithCompletionToken:(TOCCancelToken*)completionToken {
    TOCFuture* future = [TOCFuture new];
    future->_completionToken = completionToken;
    return future;
}

-(bool) __ForSource__tryStartFutureSet {
    @synchronized(self) {
        if (_hasBeenSet) return false;
        _hasBeenSet = true;
    }
    return true;
}
-(void) __ForSource__forceFinishFutureSet:(TOCFuture*)finalValue {
    require(finalValue != nil);
    require([self __trySet:finalValue->_value
                 succeeded:finalValue->_ifDoneHasSucceeded
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
        if (_hasBeenSet && !unwiring) return false;
        _hasBeenSet = true;
        _value = finalValue;
        _ifDoneHasSucceeded = succeeded;
    }
    return true;
}


-(TOCCancelToken*) cancelledOnCompletionToken {
    return _completionToken;
}

-(enum TOCFutureState) state {
    enum TOCCancelTokenState completionState = _completionToken.state;
    switch (completionState) {
        case TOCCancelTokenState_Cancelled:
            return _ifDoneHasSucceeded ? TOCFutureState_CompletedWithResult : TOCFutureState_Failed;
            
        case TOCCancelTokenState_Immortal:
            return TOCFutureState_EternallyIncomplete;
            
        default:
            require(completionState == TOCCancelTokenState_StillCancellable);
            return TOCFutureState_StillCompletable;
    }
}
-(bool)isIncomplete {
    return ![_completionToken isAlreadyCancelled];
}
-(bool)hasResult {
    return self.state == TOCFutureState_CompletedWithResult;
}
-(bool)hasFailed {
    return self.state == TOCFutureState_Failed;
}
-(id)forceGetResult {
    require([self hasResult]);
    return _value;
}
-(id)forceGetFailure {
    require([self hasFailed]);
    return _value;
}

-(void)finallyDo:(TOCFutureFinallyHandler)completionHandler
          unless:(TOCCancelToken *)unlessCancelledToken {
    require(completionHandler != nil);
    
    __unsafe_unretained TOCFuture* weakSelf = self;
    [_completionToken whenCancelledDo:^{ completionHandler(weakSelf); }
                               unless:unlessCancelledToken];
}

-(void)thenDo:(TOCFutureThenHandler)resultHandler
       unless:(TOCCancelToken *)unlessCancelledToken {
    require(resultHandler != nil);
    
    [self finallyDo:^(TOCFuture *completed) {
        if (completed->_ifDoneHasSucceeded) {
            resultHandler(completed->_value);
        }
    } unless:unlessCancelledToken];
}

-(void)catchDo:(TOCFutureCatchHandler)failureHandler
        unless:(TOCCancelToken *)unlessCancelledToken {
    require(failureHandler != nil);
    
    [self finallyDo:^(TOCFuture *completed) {
        if (!completed->_ifDoneHasSucceeded) {
            failureHandler(completed->_value);
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
    } unless:resultSource.future->_completionToken];
    
    return resultSource.future;
}

-(TOCFuture *)then:(TOCFutureThenContinuation)resultContinuation unless:(TOCCancelToken *)unlessCancelledToken {
    require(resultContinuation != nil);
    
    return [self finally:^id(TOCFuture *completed) {
        if (completed->_ifDoneHasSucceeded) {
            return resultContinuation(completed->_value);
        } else {
            return completed;;
        }
    } unless:unlessCancelledToken];
}

-(TOCFuture *)catch:(TOCFutureCatchContinuation)failureContinuation
             unless:(TOCCancelToken *)unlessCancelledToken {
    require(failureContinuation != nil);
    
    return [self finally:^(TOCFuture *completed) {
        if (completed->_ifDoneHasSucceeded) {
            return completed->_value;
        } else {
            return failureContinuation(completed->_value);
        }
    } unless:unlessCancelledToken];
}

-(NSString*) description {
    @synchronized(self) {
        enum TOCCancelTokenState completionState = _completionToken.state;
        
        if (completionState == TOCCancelTokenState_Immortal) {
            return @"Incomplete Future [Eternal]";
        }
        
        if (completionState == TOCCancelTokenState_StillCancellable) {
            if (_hasBeenSet) return @"Incomplete Future [Set]";
            return @"Incomplete Future";
        }
        
        return [NSString stringWithFormat:@"Future with %@: %@",
                _ifDoneHasSucceeded ? @"Result" : @"Failure",
                _value];
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
