#import "TOCCancelTokenAndSource.h"
#import "Internal.h"
#include <libkern/OSAtomic.h>

typedef void (^Remover)(void);
typedef void (^SettledHandler)(enum TOCCancelTokenState state);

static TOCCancelToken* SharedCancelledToken = nil;
static TOCCancelToken* SharedImmortalToken = nil;

@implementation TOCCancelToken {
@private NSMutableArray* _cancelHandlers;
@private NSMutableSet* _removableSettledHandlers; // run when the token is cancelled or immortal
@private enum TOCCancelTokenState _state;
}

+(void) initialize {
    SharedCancelledToken = [TOCCancelToken new];
    SharedCancelledToken->_state = TOCCancelTokenState_Cancelled;
    
    SharedImmortalToken = [TOCCancelToken new];
    assert(SharedImmortalToken->_state == TOCCancelTokenState_Immortal); // default state should be immortal
}

+(TOCCancelToken *)cancelledToken {
    return SharedCancelledToken;
}

+(TOCCancelToken *)immortalToken {
    return SharedImmortalToken;
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
        handler(_state);
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
        handler(_state);
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

-(void)whenCancelledDo:(TOCCancelHandler)cancelHandler {
    require(cancelHandler != nil);
    @synchronized(self) {
        if (_state == TOCCancelTokenState_Immortal) return;
        if (_state == TOCCancelTokenState_StillCancellable) {
            [_cancelHandlers addObject:cancelHandler];
            return;
        }
    }
    
    cancelHandler();
}

-(Remover)_removable_whenSettledDo:(SettledHandler)settledHandler {
    require(settledHandler != nil);
    @synchronized(self) {
        if (_state == TOCCancelTokenState_StillCancellable) {
            // to ensure we don't end up with two distinct copies of the block, move it to a local
            // (otherwise one copy will be made when adding to the array, and another when storing to the remove closure)
            // (so without this line, the added handler wouldn't be guaranteed removable, because the remover will try to remove the wrong instance)
            SettledHandler singleCopyOfHandler = [settledHandler copy];
            
            [_removableSettledHandlers addObject:singleCopyOfHandler];
            
            return ^{
                @synchronized(self) {
                    [_removableSettledHandlers removeObject:singleCopyOfHandler];
                }
            };
        }
    }
    
    settledHandler(_state);
    return nil;
}

-(void) whenCancelledDo:(TOCCancelHandler)cancelHandler
                 unless:(TOCCancelToken*)unlessCancelledToken {
    require(cancelHandler != nil);
    
    // fair warning: the following code is very difficult to get right.
    
    // optimistically do less work
    if (unlessCancelledToken == nil) {
        [self whenCancelledDo:cancelHandler];
        return;
    }
    enum TOCCancelTokenState peekOtherState = unlessCancelledToken.state;
    if (unlessCancelledToken == self || peekOtherState == TOCCancelTokenState_Cancelled) {
        return;
    }
    if (peekOtherState == TOCCancelTokenState_Immortal) {
        [self whenCancelledDo:cancelHandler];
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
    __block Remover removeHandlerFromSelfToOther = [self _removable_whenSettledDo:^(enum TOCCancelTokenState finalState){
        if (finalState == TOCCancelTokenState_Cancelled) {
            cancelHandler();
        }
        onSecondCallRemoveHandlerFromOtherToSelf();
    }];
    removeHandlerFromOtherToSelf = [unlessCancelledToken _removable_whenSettledDo:^(enum TOCCancelTokenState finalState) {
        if (removeHandlerFromSelfToOther == nil) return; // only occurs when the handler was already run and discarded anyways
        removeHandlerFromSelfToOther();
        removeHandlerFromSelfToOther = nil;
    }];
    
    // allow the cycle to be broken
    onSecondCallRemoveHandlerFromOtherToSelf();
}

-(NSString*) description {
    @synchronized(self) {
        if (_state == TOCCancelTokenState_Immortal) return @"Uncancelled Token (Immortal)";
        if (_state == TOCCancelTokenState_Cancelled) return @"Cancelled Token";
        return @"Uncancelled Token";
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
