#import "TOCCancelToken.h"
#import "TOCCommonDefs.h"
#include <libkern/OSAtomic.h>

#define TOKEN_STATE_IMMORTAL 0 // nil defaults to immortal, so must use default int
#define TOKEN_STATE_CANCELLED -1
#define TOKEN_STATE_MORTAL 1

typedef void (^Remover)(void);

@implementation TOCCancelToken {
@private NSMutableArray* cancelHandlers;
@private bool isImmortal;
}

+(TOCCancelToken *)cancelledToken {
    return [TOCCancelToken new];
}

+(TOCCancelToken *)immortalToken {
    TOCCancelToken* token = [TOCCancelToken new];
    token->isImmortal = true;
    return token;
}

+(TOCCancelToken*) __ForSource_cancellableToken {
    TOCCancelToken* token = [TOCCancelToken new];
    token->cancelHandlers = [NSMutableArray array];
    return token;
}
-(bool) __ForSource_tryImmortalize {
    @synchronized(self) {
        if (cancelHandlers == nil) return false;
        cancelHandlers = nil;
        isImmortal = true;
    }
    return true;
}
-(bool) __ForSource_tryCancel {
    NSArray* cancelHandlerAtCancelTime;
    @synchronized(self) {
        if (cancelHandlers == nil) return false;
        
        cancelHandlerAtCancelTime = cancelHandlers;
        cancelHandlers = nil;
    }
    
    for (TOCCancelHandler handler in cancelHandlerAtCancelTime) {
        handler();
    }
    return true;
}

-(bool)isAlreadyCancelled {
    @synchronized(self) {
        return cancelHandlers == nil && !isImmortal;
    }
}
-(int)__peekTokenState {
    @synchronized(self) {
        if (cancelHandlers != nil) return TOKEN_STATE_MORTAL;
        if (isImmortal) return TOKEN_STATE_IMMORTAL;
        return TOKEN_STATE_CANCELLED;
    }
}

-(void)whenCancelledDo:(TOCCancelHandler)cancelHandler {
    require(cancelHandler != nil);
    @synchronized(self) {
        if (isImmortal) return;
        if (cancelHandlers != nil) {
            [cancelHandlers addObject:[cancelHandler copy]];
            return;
        }
    }
    
    cancelHandler();
}

-(Remover)__removable_whenCancelledDo:(TOCCancelHandler)cancelHandler {
    require(cancelHandler != nil);
    @synchronized(self) {
        if (isImmortal) return ^{};
        if (cancelHandlers != nil) {
            TOCCancelHandler handlerCopy = [cancelHandler copy];
            [cancelHandlers addObject:handlerCopy];
            return ^{ [self->cancelHandlers removeObject:handlerCopy]; };
        }
    }
    
    cancelHandler();
    return ^{};
}

-(void) whenCancelledDo:(TOCCancelHandler)cancelHandler
        unlessCancelled:(TOCCancelToken*)unlessCancelledToken {
    require(cancelHandler != nil);
    int peekUnlessCancelledTokenState = [unlessCancelledToken __peekTokenState];

    // optimistically use the unconditional whenCancelledDo
    if (peekUnlessCancelledTokenState == TOKEN_STATE_IMMORTAL || unlessCancelledToken == self) {
        [self whenCancelledDo:cancelHandler];
        return;
    }
    
    // optimistically avoid doing anything
    if (peekUnlessCancelledTokenState == TOKEN_STATE_CANCELLED) {
        return;
    }
    
    // make a block that must be called twice to break the cancelling-each-other cycle
    // that way we can be sure we don't touch an un-initialized part of the cycle, by making one call only once setup is complete
    __block int callCount;
    __block Remover removeHandlerFromOtherToSelf = nil;
    Remover onSecondCallRemoveHandlerFromOtherToSelf = ^{
        if (OSAtomicIncrement32(&callCount) == 1) return;
        assert(removeHandlerFromOtherToSelf != nil);
        removeHandlerFromOtherToSelf();
    };
    
    // make the cancel-each-other cycle, running the cancel handler if self is cancelled first
    Remover removeHandlerFromSelfToOther = [self __removable_whenCancelledDo:^{
        cancelHandler();
        onSecondCallRemoveHandlerFromOtherToSelf();
    }];
    removeHandlerFromOtherToSelf = [unlessCancelledToken __removable_whenCancelledDo:^{
        removeHandlerFromSelfToOther();
    }];
    
    // allow the cycle to be broken
    onSecondCallRemoveHandlerFromOtherToSelf();
}

-(NSString*) description {
    @synchronized(self) {
        if (isImmortal) return @"Uncancelled Token (Immortal)";
        if (cancelHandlers == nil) return @"Cancelled Token";
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
    @synchronized(self) {
        return [super description];
    }
}

@end
