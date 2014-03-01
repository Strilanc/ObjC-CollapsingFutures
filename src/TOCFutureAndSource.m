#import "TOCFutureAndSource.h"
#import "TOCInternal.h"
#import "TOCTimeout.h"
#import "UnionFind.h"

static NSObject* getSharedCycleDetectionLock() {
    static dispatch_once_t once;
    static NSObject* lock = nil;
    dispatch_once(&once, ^{
        lock = [NSObject new];
    });
    return lock;
}

enum StartUnwrapResult {
    StartUnwrapResult_CycleDetected,
    StartUnwrapResult_Started,
    StartUnwrapResult_StartedAndFinished,
    StartUnwrapResult_AlreadySet
};

@implementation TOCFuture {
/// The future's final result, final failure, or flattening target
@private id _value;
/// Whether or not the future has already been told to flatten or complete or fail
@private bool _hasBeenSet;
/// Whether or not the future has succeeded vs failed
@private bool _ifDoneHasSucceeded;

/// Callback functionality is delegated to this token
/// It is only cancelled *after* the above state fields have been set
@private TOCCancelToken* _completionToken;

/// Used for detection of immortal flattening cycles
/// Must hold getSharedCycleDetectionLock() when touching this node
@private UFDisjointSetNode* _cycleNode;
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

-(UFDisjointSetNode*) _getInitCycleNode {
    if (_cycleNode == nil) _cycleNode = [UFDisjointSetNode new];
    return _cycleNode;
}

-(enum StartUnwrapResult) _ForSource_tryStartUnwrapping:(TOCFuture*)targetFuture {
    TOCInternal_need(targetFuture != nil);
    
    // try set (without completing)
    @synchronized(self) {
        if (_hasBeenSet) return StartUnwrapResult_AlreadySet;
        _hasBeenSet = true;
    }
    
    // optimistically finish without doing cycle stuff
    if (!targetFuture.isIncomplete) {
        [self _ForSource_forceUnwrapToComplete:targetFuture];
        return StartUnwrapResult_StartedAndFinished;
    }
    
    // look for flattening cycles
    @synchronized(getSharedCycleDetectionLock()) {
        bool didMerge = [self._getInitCycleNode unionWith:targetFuture._getInitCycleNode];
        if (!didMerge) {
            // it's not necessary to clear the cycle nodes, but it frees up some memory
            // other futures in the cycle won't get their cycle nodes cleared
            // but node chains should be in EXTREMELY shallow trees
            // and the nodes can't keep futures alive, so there's no reference cycle
            _cycleNode = nil;
            targetFuture->_cycleNode = nil;
            return StartUnwrapResult_CycleDetected;
        }
    }
    
    return StartUnwrapResult_Started;
}
-(void) _ForSource_forceUnwrapToComplete:(TOCFuture*)future {
    TOCInternal_force(future != nil);
    TOCInternal_force(!future.isIncomplete);
    
    bool flatteningFutureSucceeded = [self _trySetOrComplete:future->_value
                                                   succeeded:future->_ifDoneHasSucceeded
                                                  isUnwiring:true];
    TOCInternal_force(flatteningFutureSucceeded);
}
-(bool) _ForSource_tryComplete:(id)finalValue
                     succeeded:(bool)succeeded {
    return [self _trySetOrComplete:finalValue
                         succeeded:succeeded
                        isUnwiring:false];
}
-(bool) _trySetOrComplete:(id)finalValue
                succeeded:(bool)succeeded
               isUnwiring:(bool)unwiring {
    
    TOCInternal_need(![finalValue isKindOfClass:[TOCFuture class]]);
    
    @synchronized(self) {
        if (_hasBeenSet && !unwiring) return false;
        _hasBeenSet = true;
        _value = finalValue;
        _ifDoneHasSucceeded = succeeded;
    }
    @synchronized(getSharedCycleDetectionLock()) {
        _cycleNode = nil;
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
            TOCInternal_unexpectedEnum(completionCancelTokenState);
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
    TOCInternal_force(self.hasResult);
    return _value;
}
-(id)forceGetFailure {
    TOCInternal_force(self.hasFailed);
    return _value;
}

-(void)finallyDo:(TOCFutureFinallyHandler)completionHandler
          unless:(TOCCancelToken *)unlessCancelledToken {
    TOCInternal_need(completionHandler != nil);
    
    // It is safe to reference 'self' here, despite it creating a reference cycle. The cycle is not self-sustaining.
    // The reason comes down to future sources and tokens sources causing their future/token to discard callbacks when the source is deallocated.
    // The cycle this call creates would be broken by a source being deallocated, but the source is not part of the created cycle.
    // So it should be safe. The created cycle is still dependent.
    // (If completionHandler has a closure including a source, the cycle would be self-sustaining whether or not we added this extra bit.)
    [_completionToken whenCancelledDo:^{ completionHandler(self); }
                               unless:unlessCancelledToken];
}

-(void)thenDo:(TOCFutureThenHandler)resultHandler
       unless:(TOCCancelToken *)unlessCancelledToken {
    TOCInternal_need(resultHandler != nil);
    
    [self finallyDo:^(TOCFuture *completed) {
        if (completed->_ifDoneHasSucceeded) {
            resultHandler(completed->_value);
        }
    } unless:unlessCancelledToken];
}

-(void)catchDo:(TOCFutureCatchHandler)failureHandler
        unless:(TOCCancelToken *)unlessCancelledToken {
    TOCInternal_need(failureHandler != nil);
    
    [self finallyDo:^(TOCFuture *completed) {
        if (!completed->_ifDoneHasSucceeded) {
            failureHandler(completed->_value);
        }
    } unless:unlessCancelledToken];
}

-(TOCFuture *)finally:(TOCFutureFinallyContinuation)completionContinuation
               unless:(TOCCancelToken *)unlessCancelledToken {
    TOCInternal_need(completionContinuation != nil);
    
    TOCFutureSource* resultSource = [TOCFutureSource futureSourceUntil:unlessCancelledToken];
    
    [self finallyDo:^(TOCFuture *completed) { [resultSource trySetResult:completionContinuation(completed)]; }
             unless:unlessCancelledToken];
    
    return resultSource.future;
}

-(TOCFuture *)then:(TOCFutureThenContinuation)resultContinuation
            unless:(TOCCancelToken *)unlessCancelledToken {
    TOCInternal_need(resultContinuation != nil);
    
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
    TOCInternal_need(failureContinuation != nil);
    
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
-(BOOL)isEqual:(id)object {
    if (self == object) return YES;
    if (![object isKindOfClass:TOCFuture.class]) return NO;
    return [self isEqualToFuture:(TOCFuture*)object];
}
-(BOOL)isEqualToFuture:(TOCFuture *)other {
    if (self == other) return YES;
    if (other == nil) return NO;

    enum TOCFutureState state1 = self.state;
    enum TOCFutureState state2 = other.state;
    if (state1 != state2) return NO;
    
    switch (state1) {
        case TOCFutureState_Immortal:
            return YES;
            
        case TOCFutureState_CompletedWithResult:
        case TOCFutureState_Failed:
            return _value == other->_value || [_value isEqual:other->_value];

        case TOCFutureState_Flattening:
        case TOCFutureState_AbleToBeSet:
        default:
            return NO;
    }
}
-(NSUInteger)hash {
    enum TOCFutureState state = self.state;
    switch (state) {
        case TOCFutureState_Immortal:
            return NSUIntegerMax;
            
        case TOCFutureState_CompletedWithResult:
            return [_value hash];

        case TOCFutureState_Failed:
            return ~[_value hash];
            
        case TOCFutureState_Flattening:
        case TOCFutureState_AbleToBeSet:
        default:
            return super.hash;
    }
}

@end

@implementation TOCFutureSource {
@private TOCCancelTokenSource* _cancelledOnCompletedSource_ClearedOnSet;
}

@synthesize future;

-(TOCFutureSource*) init {
    self = [super init];
    if (self) {
        self->_cancelledOnCompletedSource_ClearedOnSet = [TOCCancelTokenSource new];
        self->future = [TOCFuture _ForSource_completableFutureWithCompletionToken:self->_cancelledOnCompletedSource_ClearedOnSet.token];
    }
    return self;
}

+(TOCFutureSource*) futureSourceUntil:(TOCCancelToken*)untilCancelledToken {
    TOCFutureSource* source = [TOCFutureSource new];
    [untilCancelledToken whenCancelledDo:^{ [source trySetFailedWithCancel]; }
                                  unless:source.future.cancelledOnCompletionToken];
    return source;
}

-(bool) _trySetAndFlattenResult:(TOCFuture*)result {
    enum StartUnwrapResult startUnwrapResult = [future _ForSource_tryStartUnwrapping:result];
    
    bool didNotSet = startUnwrapResult == StartUnwrapResult_AlreadySet;
    if (didNotSet) return false;
    
    // transfer the only reference to the completion source into a local now, so we don't have to clear it in multiple cases
    TOCCancelTokenSource* cancelledOnCompletedSource = _cancelledOnCompletedSource_ClearedOnSet;
    _cancelledOnCompletedSource_ClearedOnSet = nil;
    
    switch (startUnwrapResult) {
        case StartUnwrapResult_StartedAndFinished:
            // nice: the result was already completed
            // cancel completion source to propagate that completion
            [cancelledOnCompletedSource cancel];
            break;
            
        case StartUnwrapResult_CycleDetected:
            // this future will never complete
            // just allow our completion source to be discarded without being cancelled
            // that way its token will become immortal and our future will also become immortal
            break;
            
        case StartUnwrapResult_Started: {
            // future will complete later
            // keep completion source alive in closure until it can be cancelled
            // if result becomes immortal, the closure will be discarded and take the source with it (making our future immortal as well)
            [result.cancelledOnCompletionToken whenCancelledDo:^{
                // future must be ready to be accessed before we propagate completion
                [self->future _ForSource_forceUnwrapToComplete:result];
                [cancelledOnCompletedSource cancel];
            }];
            break;
            
        } default:
            // already checked StartUnwrapResult_AlreadySet above
            TOCInternal_unexpectedEnum(startUnwrapResult);
    }
    
    // this source is set (i.e. it can't be set anymore), even if its future is not completed yet or ever
    return true;
}
-(bool) _tryComplete:(id)value succeeded:(bool)succeeded {
    bool didSet = [future _ForSource_tryComplete:value succeeded:succeeded];
    if (!didSet) return false;
    
    [_cancelledOnCompletedSource_ClearedOnSet cancel];
    _cancelledOnCompletedSource_ClearedOnSet = nil;
    return true;
}

-(bool) trySetResult:(id)result {
    // automatic flattening
    if ([result isKindOfClass:[TOCFuture class]]) {
        return [self _trySetAndFlattenResult:result];
    }
    
    return [self _tryComplete:result succeeded:true];
}
-(bool) trySetFailure:(id)failure {
    return [self _tryComplete:failure succeeded:false];
}
-(bool) trySetFailedWithCancel {
    return [self trySetFailure:TOCCancelToken.cancelledToken];
}
-(bool) trySetFailedWithTimeout {
    return [self trySetFailure:[TOCTimeout new]];
}

-(void) forceSetResult:(id)result {
    TOCInternal_force([self trySetResult:result]);
}
-(void) forceSetFailure:(id)failure {
    TOCInternal_force([self trySetFailure:failure]);
}
-(void) forceSetFailedWithCancel {
    TOCInternal_force([self trySetFailedWithCancel]);
}
-(void) forceSetFailedWithTimeout {
    TOCInternal_force([self trySetFailedWithTimeout]);
}

-(NSString*) description {
    return [NSString stringWithFormat:@"Future Source: %@", future];
}

@end
