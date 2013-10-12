#import "TOCCancelToken.h"
#import "TOCCommonDefs.h"
#include <libkern/OSAtomic.h>

#define TOKEN_STATE_IMMORTAL 0 // nil defaults to immortal, so must use default int
#define TOKEN_STATE_CANCELLED -1
#define TOKEN_STATE_MORTAL 1

typedef void (^Remover)(void);
typedef void (^SettledHandler)(int state);

@implementation TOCCancelToken {
@private NSMutableArray* cancelHandlers;
@private NSMutableSet* removableSettledHandlers; // run when the token is cancelled or immortal
@private int state;
@private NSObject* lock;
}

-(id) init {
    if (self = [super init]) {
        self->lock = [NSObject new];
    }
    return self;
}
+(TOCCancelToken *)cancelledToken {
    TOCCancelToken* token = [TOCCancelToken new];
    token->state = TOKEN_STATE_CANCELLED;
    return token;
}

+(TOCCancelToken *)immortalToken {
    TOCCancelToken* token = [TOCCancelToken new];
    assert(token->state == TOKEN_STATE_IMMORTAL); // default state should be immortal
    return token;
}

+(TOCCancelToken*) __ForSource_cancellableToken {
    TOCCancelToken* token = [TOCCancelToken new];
    token->cancelHandlers = [NSMutableArray array];
    token->removableSettledHandlers = [NSMutableSet set];
    token->state = TOKEN_STATE_MORTAL;
    return token;
}
-(bool) __ForSource_tryImmortalize {
    NSSet* settledHandlersSnapshot;
    @synchronized(lock) {
        if (state != TOKEN_STATE_MORTAL) return false;
        state = TOKEN_STATE_IMMORTAL;
        
        // need to copy+clear settled handlers, instead of just nil-ing the ref, because indirect references to it escape and may be kept alive indefinitely
        settledHandlersSnapshot = [removableSettledHandlers copy];
        [removableSettledHandlers removeAllObjects];
        removableSettledHandlers = nil;

        cancelHandlers = nil;
    }
    
    for (SettledHandler handler in settledHandlersSnapshot) {
        handler(state);
    }
    return true;
}
-(bool) __ForSource_tryCancel {
    NSArray* cancelHandlersSnapshot;
    NSSet* settledHandlersSnapshot;
    @synchronized(lock) {
        if (state != TOKEN_STATE_MORTAL) return false;
        state = TOKEN_STATE_CANCELLED;
        
        cancelHandlersSnapshot = cancelHandlers;
        cancelHandlers = nil;

        // need to copy+clear settled handlers, instead of just nil-ing the ref, because indirect references to it escape and may be kept alive indefinitely
        settledHandlersSnapshot = [removableSettledHandlers copy];
        [removableSettledHandlers removeAllObjects];
        removableSettledHandlers = nil;
    }
    
    for (TOCCancelHandler handler in cancelHandlersSnapshot) {
        handler();
    }
    for (SettledHandler handler in settledHandlersSnapshot) {
        handler(state);
    }
    return true;
}

-(bool)isAlreadyCancelled {
    return [self __peekTokenState] == TOKEN_STATE_CANCELLED;
}
-(bool)canStillBeCancelled {
    return [self __peekTokenState] == TOKEN_STATE_MORTAL;
}
-(int)__peekTokenState {
    @synchronized(lock) {
        return state;
    }
}

-(void)whenCancelledDo:(TOCCancelHandler)cancelHandler {
    require(cancelHandler != nil);
    @synchronized(lock) {
        if (state == TOKEN_STATE_IMMORTAL) return;
        if (state == TOKEN_STATE_MORTAL) {
            [cancelHandlers addObject:[cancelHandler copy]];
            return;
        }
    }
    
    cancelHandler();
}

-(Remover)__removable_whenSettledDo:(SettledHandler)settledHandler {
    require(settledHandler != nil);
    @synchronized(lock) {
        if (state == TOKEN_STATE_MORTAL) {
            TOCCancelHandler handlerCopy = [settledHandler copy];
            [removableSettledHandlers addObject:handlerCopy];

            // avoid closing over 'self' in the remover, just to be safe
            id lockRef = lock;
            NSMutableSet* removableSettledHandlersRef = removableSettledHandlers;
            return ^{
                @synchronized(lockRef) {
                    [removableSettledHandlersRef removeObject:handlerCopy];
                }
            };
        }
    }
    
    settledHandler(state);
    return ^{};
}

-(void) whenCancelledDo:(TOCCancelHandler)cancelHandler
        unlessCancelled:(TOCCancelToken*)unlessCancelledToken {
    require(cancelHandler != nil);
    int peekOtherState = [unlessCancelledToken __peekTokenState];

    // optimistically do nothing
    if (unlessCancelledToken == self || peekOtherState == TOKEN_STATE_CANCELLED) {
        return;
    }
    
    // optimistically use the unconditional whenCancelledDo
    if (peekOtherState == TOKEN_STATE_IMMORTAL) {
        [self whenCancelledDo:cancelHandler];
        return;
    }
    
    // make a block that must be called twice to break the cancelling-each-other cycle
    // that way we can be sure we don't touch an un-initialized part of the cycle, by making one call only once setup is complete
    __block int callCount = 0;
    __block Remover removeHandlerFromOtherToSelf = nil;
    Remover onSecondCallRemoveHandlerFromOtherToSelf = ^{
        if (OSAtomicIncrement32(&callCount) == 1) return;
        assert(removeHandlerFromOtherToSelf != nil);
        removeHandlerFromOtherToSelf();
        removeHandlerFromOtherToSelf = nil;
    };
    
    // make the cancel-each-other cycle, running the cancel handler if self is cancelled first
    __block Remover removeHandlerFromSelfToOther = [self __removable_whenSettledDo:^(int finalState){
        if (finalState == TOKEN_STATE_CANCELLED) {
            cancelHandler();
        }
        onSecondCallRemoveHandlerFromOtherToSelf();
    }];
    removeHandlerFromOtherToSelf = [unlessCancelledToken __removable_whenSettledDo:^(int finalState) {
        removeHandlerFromSelfToOther();
        removeHandlerFromSelfToOther = nil;
    }];
    
    // allow the cycle to be broken
    onSecondCallRemoveHandlerFromOtherToSelf();
}

-(NSString*) description {
    @synchronized(lock) {
        if (state == TOKEN_STATE_IMMORTAL) return @"Uncancelled Token (Immortal)";
        if (state == TOKEN_STATE_CANCELLED) return @"Cancelled Token";
        return @"Uncancelled Token";
    }
}

@end

@implementation TOCCancelTokenSource

@synthesize token;

-(TOCCancelTokenSource*) init {
    self = [super init];
    if (self) {
        self->token = [TOCCancelToken __ForSource_cancellableToken];
    }
    return self;
}

-(void) dealloc {
    [token __ForSource_tryImmortalize];
}
-(void) cancel {
    [self tryCancel];
}
-(bool)tryCancel {
    return [token __ForSource_tryCancel];
}

-(NSString*) description {
    return [NSString stringWithFormat:@"Cancel Token Source: %@", token];
}

@end
