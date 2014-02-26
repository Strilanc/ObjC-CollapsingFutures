#import "TOCCancelTokenAndSource.h"
#import "TOCFutureAndSource.h"
#import "TOCInternal.h"
#include <libkern/OSAtomic.h>

typedef void (^Remover)(void);
typedef void (^SettledHandler)(void);

@implementation TOCCancelToken {
@private NSMutableArray* _cancelHandlers;
@private NSMutableSet* _removableSettledHandlers; // run when the token is cancelled or immortal
@private enum TOCCancelTokenState _state;
}

+(TOCCancelToken *)cancelledToken {
    static dispatch_once_t once;
    static TOCCancelToken* token = nil;
    dispatch_once(&once, ^{
        token = [TOCCancelToken new];
        token->_state = TOCCancelTokenState_Cancelled;
    });
    return token;
}

+(TOCCancelToken *)immortalToken {
    static dispatch_once_t once;
    static TOCCancelToken* token = nil;
    dispatch_once(&once, ^{
        token = [TOCCancelToken new];
        // default state should be immortal
        assert(token->_state == TOCCancelTokenState_Immortal);
    });
    return token;
}

+(TOCCancelToken*) _ForSource_cancellableToken {
    TOCCancelToken* token = [TOCCancelToken new];
    token->_cancelHandlers = [NSMutableArray array];
    token->_removableSettledHandlers = [NSMutableSet set];
    token->_state = TOCCancelTokenState_StillCancellable;
    return token;
}
-(bool) _ForSource_tryImmortalize {
    NSSet* settledHandlersSnapshot;
    @synchronized(self) {
        if (_state != TOCCancelTokenState_StillCancellable) return false;
        _state = TOCCancelTokenState_Immortal;
        
        // need to copy+clear settled handlers, instead of just nil-ing the ref, because indirect references to it escape and may be kept alive indefinitely
        settledHandlersSnapshot = [_removableSettledHandlers copy];
        [_removableSettledHandlers removeAllObjects];
        _removableSettledHandlers = nil;
        
        _cancelHandlers = nil;
    }
    
    for (SettledHandler handler in settledHandlersSnapshot) {
        handler();
    }
    return true;
}
-(bool) _ForSource_tryCancel {
    NSArray* cancelHandlersSnapshot;
    NSSet* settledHandlersSnapshot;
    @synchronized(self) {
        if (_state != TOCCancelTokenState_StillCancellable) return false;
        _state = TOCCancelTokenState_Cancelled;
        
        cancelHandlersSnapshot = _cancelHandlers;
        _cancelHandlers = nil;
        
        // need to copy+clear settled handlers, instead of just nil-ing the ref, because indirect references to it escape and may be kept alive indefinitely
        settledHandlersSnapshot = [_removableSettledHandlers copy];
        [_removableSettledHandlers removeAllObjects];
        _removableSettledHandlers = nil;
    }
    
    for (TOCCancelHandler handler in cancelHandlersSnapshot) {
        handler();
    }
    for (SettledHandler handler in settledHandlersSnapshot) {
        handler();
    }
    return true;
}

-(enum TOCCancelTokenState)state {
    @synchronized(self) {
        return _state;
    }
}
-(bool)isAlreadyCancelled {
    return self.state == TOCCancelTokenState_Cancelled;
}
-(bool)canStillBeCancelled {
    return self.state == TOCCancelTokenState_StillCancellable;
}

-(TOCCancelHandler) _preserveMainThreadness:(TOCCancelHandler)cancelHandler {
    if (!NSThread.isMainThread) return cancelHandler;
    
    return ^{ [TOCInternal_BlockObject performBlock:cancelHandler
                                           onThread:NSThread.mainThread]; };
}

-(TOCCancelHandler) _preserveMainThreadness:(TOCCancelHandler)cancelHandler
                                   andCheck:(TOCCancelToken*)unlessCancelledToken {
    if (!NSThread.isMainThread) return cancelHandler;
    
    return [self _preserveMainThreadness:^{
        // do a final check, to help the caller out
        // consider: if the unless token was cancelled after this token, but before the callback reached the main thread
        // in that situation, the caller may have already done UI things based on observing that the token was cancelled
        // they may be *extremely* surprised by the callback running their cleanup stuff again
        // we don't want to surprise them, so we do this polite check before calling
        if (unlessCancelledToken.isAlreadyCancelled) return;
        
        cancelHandler();
    }];
}

-(void)whenCancelledDo:(TOCCancelHandler)cancelHandler {
    TOCInternal_need(cancelHandler != nil);
    
    @synchronized(self) {
        if (_state == TOCCancelTokenState_Immortal) return;
        if (_state == TOCCancelTokenState_StillCancellable) {
            TOCCancelHandler safeHandler = [self _preserveMainThreadness:cancelHandler];
            [_cancelHandlers addObject:safeHandler];
            return;
        }
    }
    
    cancelHandler();
}

-(Remover)_removable_whenSettledDo:(SettledHandler)settledHandler {
    TOCInternal_need(settledHandler != nil);
    @synchronized(self) {
        if (_state == TOCCancelTokenState_StillCancellable) {
            // to ensure we don't end up with two distinct copies of the block, move it to a local
            // (otherwise one copy will be made when adding to the array, and another when storing to the remove closure)
            // (so without this line, the added handler wouldn't be guaranteed removable, because the remover will try to remove the wrong instance)
            SettledHandler singleCopyOfHandler = [settledHandler copy];
            
            [_removableSettledHandlers addObject:singleCopyOfHandler];
            
            return ^{
                @synchronized(self) {
                    [self->_removableSettledHandlers removeObject:singleCopyOfHandler];
                }
            };
        }
    }
    
    settledHandler();
    return nil;
}

-(void) whenCancelledDo:(TOCCancelHandler)cancelHandler
                 unless:(TOCCancelToken*)unlessCancelledToken {
    TOCInternal_need(cancelHandler != nil);
    
    // fair warning: the following code is very difficult to get right.
    
    // optimistically do less work
    enum TOCCancelTokenState peekOtherState = unlessCancelledToken.state;
    if (peekOtherState == TOCCancelTokenState_Immortal) {
        [self whenCancelledDo:cancelHandler];
        return;
    }
    if (unlessCancelledToken == self || peekOtherState == TOCCancelTokenState_Cancelled) {
        return;
    }
    
    // make a block that must be called twice to break the cancelling-each-other cycle
    // that way we can be sure we don't touch an un-initialized part of the cycle, by making one call only once setup is complete
    __block int callCount = 0;
    __block Remover removeHandlerFromOtherToSelf = nil;
    Remover onSecondCallRemoveHandlerFromOtherToSelf = ^{
        if (OSAtomicIncrement32Barrier(&callCount) == 1) return;
        if (removeHandlerFromOtherToSelf == nil) return; // only occurs when the handler was already run and discarded anyways
        removeHandlerFromOtherToSelf();
        removeHandlerFromOtherToSelf = nil;
    };
    
    // make the cancel-each-other cycle, running the cancel handler if self is cancelled first
    TOCCancelHandler safeHandler = [self _preserveMainThreadness:cancelHandler
                                                        andCheck:unlessCancelledToken];
    __block Remover removeHandlerFromSelfToOther = [self _removable_whenSettledDo:^(){
        // note: this self-reference is fine because it doesn't involve self's source, and gets cleared if the source is deallocated
        if (self->_state == TOCCancelTokenState_Cancelled) {
            safeHandler();
        }
        onSecondCallRemoveHandlerFromOtherToSelf();
    }];
    removeHandlerFromOtherToSelf = [unlessCancelledToken _removable_whenSettledDo:^() {
        if (removeHandlerFromSelfToOther == nil) return; // only occurs when the handler was already run and discarded anyways
        removeHandlerFromSelfToOther();
        removeHandlerFromSelfToOther = nil;
    }];
    
    // allow the cycle to be broken
    onSecondCallRemoveHandlerFromOtherToSelf();
}

-(NSString*) description {
    switch (self.state) {
        case TOCCancelTokenState_Cancelled:
            return @"Cancelled Token";
        case TOCCancelTokenState_Immortal:
            return @"Uncancelled Token (Immortal)";
        case TOCCancelTokenState_StillCancellable:
            return @"Uncancelled Token";
        default:
            return @"Cancel token in an unrecognized state";
    }
}

@end

@implementation TOCCancelTokenSource

@synthesize token;

-(TOCCancelTokenSource*) init {
    self = [super init];
    if (self) {
        self->token = [TOCCancelToken _ForSource_cancellableToken];
    }
    return self;
}

+(TOCCancelTokenSource*) cancelTokenSourceUntil:(TOCCancelToken*)untilCancelledToken {
    TOCCancelTokenSource* source = [TOCCancelTokenSource new];
    [untilCancelledToken whenCancelledDo:^{ [source cancel]; }
                                  unless:source.token];
    return source;
}

-(void) dealloc {
    [token _ForSource_tryImmortalize];
}
-(void) cancel {
    [self tryCancel];
}
-(bool)tryCancel {
    return [token _ForSource_tryCancel];
}

-(NSString*) description {
    return [NSString stringWithFormat:@"Cancel Token Source: %@", token];
}

@end
