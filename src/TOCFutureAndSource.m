#import "TOCFutureAndSource.h"
#import "TOCInternal.h"
#import "TOCTimeout.h"

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
    future->_completionToken = TOCCancelToken.cancelledToken;
    future->_ifDoneHasSucceeded = true;
    future->_value = resultValue;
    return future;
}
+(TOCFuture *)futureWithFailure:(id)failureValue {
    TOCFuture *future = [TOCFuture new];
    future->_completionToken = TOCCancelToken.cancelledToken;
    future->_ifDoneHasSucceeded = false;
    future->_value = failureValue;
    return future;
}

+(TOCFuture*) _ForSource_completableFutureWithCompletionToken:(TOCCancelToken*)completionToken {
    TOCFuture* future = [TOCFuture new];
    future->_completionToken = completionToken;
    return future;
}

-(bool) _ForSource_tryStartFutureSet {
    @synchronized(self) {
        if (_hasBeenSet) return false;
        _hasBeenSet = true;
    }
    return true;
}
-(void) _ForSource_forceFinishFutureSet:(TOCFuture*)finalValue {
    require(finalValue != nil);
    bool flatteningFutureSucceeded = [self _trySet:finalValue->_value
                                         succeeded:finalValue->_ifDoneHasSucceeded
                                        isUnwiring:true];
    force(flatteningFutureSucceeded);
}
-(bool) _ForSource_trySet:(id)finalValue
                succeeded:(bool)succeeded {
    return [self _trySet:finalValue
               succeeded:succeeded
              isUnwiring:false];
}
-(bool) _trySet:(id)finalValue
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
            return TOCFutureState_Immortal;
            
        case TOCCancelTokenState_StillCancellable:
            @synchronized(self) {
                return _hasBeenSet ? TOCFutureState_Flattening : TOCFutureState_AbleToBeSet;
            }
            
        default: {
            bool completionStateIsRecognized = false;
            force(completionStateIsRecognized);
        }
    }
}
-(bool)isIncomplete {
    return !_completionToken.isAlreadyCancelled;
}
-(bool)hasResult {
    return self.state == TOCFutureState_CompletedWithResult;
}
-(bool)hasFailed {
    return self.state == TOCFutureState_Failed;
}
-(bool)hasFailedWithCancel {
    return self.hasFailed && [self.forceGetFailure isKindOfClass:[TOCCancelToken class]];
}
-(bool)hasFailedWithTimeout {
    return self.hasFailed && [self.forceGetFailure isKindOfClass:[TOCTimeout class]];
}
-(id)forceGetResult {
    force(self.hasResult);
    return _value;
}
-(id)forceGetFailure {
    force(self.hasFailed);
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
    [unlessCancelledToken whenCancelledTryCancelFutureSource:resultSource];
    
    return resultSource.future;
}

-(TOCFuture *)then:(TOCFutureThenContinuation)resultContinuation
            unless:(TOCCancelToken *)unlessCancelledToken {
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
    switch (self.state) {
        case TOCFutureState_CompletedWithResult:
            return [NSString stringWithFormat:@"Future with Result: %@", _value];
        case TOCFutureState_Failed:
            return [NSString stringWithFormat:@"Future with Failure: %@", _value];
        case TOCFutureState_Flattening:
            return @"Incomplete Future [Set, Flattening Result]";
        case TOCFutureState_Immortal:
            return @"Incomplete Future [Eternal]";
        case TOCFutureState_AbleToBeSet:
            return @"Incomplete Future";
        default:
            return @"Future in an unrecognized state";
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
        self->future = [TOCFuture _ForSource_completableFutureWithCompletionToken:self->completionSource.token];
    }
    return self;
}

-(bool) trySetResult:(id)finalResult {
    // automatic flattening
    if ([finalResult isKindOfClass:[TOCFuture class]]) {
        if (![future _ForSource_tryStartFutureSet]) return false;
        
        // optimize self-dependence into immortality
        if (finalResult == future) {
            completionSource = nil;
            return true;
        }
        
        [(TOCFuture*)finalResult finallyDo:^(TOCFuture *completed) {
            [future _ForSource_forceFinishFutureSet:completed];
            [completionSource cancel];
        } unless:nil];
        
        return true;
    }
    
    return [future _ForSource_trySet:finalResult succeeded:true] && [completionSource tryCancel];
}
-(bool) trySetFailure:(id)finalFailure {
    return [future _ForSource_trySet:finalFailure succeeded:false] && [completionSource tryCancel];
}
-(bool) trySetFailedWithCancel {
    return [self trySetFailure:TOCCancelToken.cancelledToken];
}
-(bool) trySetFailedWithTimeout {
    return [self trySetFailure:[TOCTimeout new]];
}

-(void) forceSetResult:(id)finalResult {
    force([self trySetResult:finalResult]);
}
-(void) forceSetFailure:(id)finalFailure {
    force([self trySetFailure:finalFailure]);
}
-(void) forceSetFailedWithCancel {
    force([self trySetFailedWithCancel]);
}
-(void) forceSetFailedWithTimeout {
    force([self trySetFailedWithTimeout]);
}

-(NSString*) description {
    return [NSString stringWithFormat:@"Future Source: %@", future];
}

@end
