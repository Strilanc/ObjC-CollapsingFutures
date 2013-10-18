#import "TOCFutureAndSource.h"
#import "TOCInternal.h"
#import "TOCTimeout.h"

static NSObject* sharedUnwrapCycleDetectionLock;
enum StartUnwrapResult {
    StartUnwrapResult_CycleDetected,
    StartUnwrapResult_Started,
    StartUnwrapResult_StartedAndFinished,
    StartUnwrapResult_AlreadySet
};

@implementation TOCFuture {
@private id _value;
@private bool _ifDoneHasSucceeded;
@private bool _hasBeenSet;
@private TOCCancelToken* _completionToken;
@private TOCFuture* _unwrapTarget;
}

+(void)initialize {
    sharedUnwrapCycleDetectionLock = [NSObject new];
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

-(enum StartUnwrapResult) _ForSource_tryStartUnwrapping:(TOCFuture*)targetFuture {
    require(targetFuture != nil);
    
    @synchronized(self) {
        if (_hasBeenSet) return StartUnwrapResult_AlreadySet;
        _hasBeenSet = true;
    }
    
    if (!targetFuture.isIncomplete) {
        [self _forceUnwrap:targetFuture];
        return StartUnwrapResult_StartedAndFinished;
    }
    
    @synchronized(sharedUnwrapCycleDetectionLock) {
        bool cycleDetected = false;
        for (TOCFuture* f = targetFuture; f != nil && !cycleDetected; f = f->_unwrapTarget) {
            cycleDetected = f == self;
        }
        if (cycleDetected) {
            // Futures unwrapping in a cycle are immortal. No need to keep links around.
            TOCFuture* f = targetFuture;
            while (true) {
                TOCFuture* n = f->_unwrapTarget;
                if (n == nil) break;
                f->_unwrapTarget = nil;
                f = n;
            }
            
            return StartUnwrapResult_CycleDetected;
        }
        self->_unwrapTarget = targetFuture;
    }
    
    return StartUnwrapResult_Started;
}
-(void) _forceUnwrap:(TOCFuture*)future {
    force(future != nil);
    force(!future.isIncomplete);
    bool flatteningFutureSucceeded = [self _trySet:future->_value
                                         succeeded:future->_ifDoneHasSucceeded
                                        isUnwiring:true];
    force(flatteningFutureSucceeded);
}
-(void) _ForSource_forceFinishUnwrap {
    TOCFuture* target;
    @synchronized(sharedUnwrapCycleDetectionLock) {
        target = _unwrapTarget;
        _unwrapTarget = nil;
    }
    [self _forceUnwrap:target];
    
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
    enum TOCCancelTokenState completionCancelTokenState = _completionToken.state;
    switch (completionCancelTokenState) {
        case TOCCancelTokenState_Cancelled:
            return _ifDoneHasSucceeded ? TOCFutureState_CompletedWithResult : TOCFutureState_Failed;
            
        case TOCCancelTokenState_Immortal:
            return TOCFutureState_Immortal;
            
        case TOCCancelTokenState_StillCancellable:
            @synchronized(self) {
                return _hasBeenSet ? TOCFutureState_Flattening : TOCFutureState_AbleToBeSet;
            }
            
        default:
            unexpectedEnum(completionCancelTokenState);
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
    
    TOCFutureSource* resultSource = [TOCFutureSource futureSourceUntil:unlessCancelledToken];
    
    [self finallyDo:^(TOCFuture *completed) { [resultSource trySetResult:completionContinuation(completed)]; }
             unless:unlessCancelledToken];
    
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
@private TOCCancelTokenSource* _completionSource;
}

@synthesize future;

-(TOCFutureSource*) init {
    self = [super init];
    if (self) {
        self->_completionSource = [TOCCancelTokenSource new];
        self->future = [TOCFuture _ForSource_completableFutureWithCompletionToken:self->_completionSource.token];
    }
    return self;
}

+(TOCFutureSource*) futureSourceUntil:(TOCCancelToken*)untilCancelledToken {
    TOCFutureSource* source = [TOCFutureSource new];
    [untilCancelledToken whenCancelledDo:^{ [source trySetFailedWithCancel]; }
                                  unless:source.future.cancelledOnCompletionToken];
    return source;
}

-(bool) trySetResult:(id)finalResult {
    // automatic flattening
    if ([finalResult isKindOfClass:[TOCFuture class]]) {
        TOCFuture* futureFinalResult = finalResult;

        enum StartUnwrapResult startUnwrapResult = [future _ForSource_tryStartUnwrapping:futureFinalResult];
        switch (startUnwrapResult) {
            case StartUnwrapResult_AlreadySet:
                return false;
            case StartUnwrapResult_StartedAndFinished:
                [self->_completionSource cancel];
                return true;
            case StartUnwrapResult_CycleDetected:
                _completionSource = nil;
                return true;
            case StartUnwrapResult_Started: {
                TOCCancelTokenSource* sourceKeptAliveByCallback = _completionSource;
                _completionSource = nil;
                [futureFinalResult.cancelledOnCompletionToken whenCancelledDo:^{
                    [self->future _ForSource_forceFinishUnwrap];
                    [sourceKeptAliveByCallback cancel];
                }];
                return true;
            } default:
                unexpectedEnum(startUnwrapResult);
        }
    }
    
    return [future _ForSource_trySet:finalResult succeeded:true] && [_completionSource tryCancel];
}
-(bool) trySetFailure:(id)finalFailure {
    return [future _ForSource_trySet:finalFailure succeeded:false] && [_completionSource tryCancel];
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
