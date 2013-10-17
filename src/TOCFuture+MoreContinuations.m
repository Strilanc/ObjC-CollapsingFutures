#import "TOCFuture+MoreContinuations.h"
#import "TOCInternal.h"

@implementation TOCFuture (MoreContinuations)

-(void)finallyDo:(TOCFutureFinallyHandler)completionHandler {
    [self finallyDo:completionHandler unless:nil];
}

-(void)thenDo:(TOCFutureThenHandler)resultHandler {
    [self thenDo:resultHandler unless:nil];
}

-(void)catchDo:(TOCFutureCatchHandler)failureHandler {
    [self catchDo:failureHandler unless:nil];
}

-(TOCFuture *)finally:(TOCFutureFinallyContinuation)completionContinuation {
    return [self finally:completionContinuation unless:nil];
}

-(TOCFuture *)then:(TOCFutureThenContinuation)resultContinuation {
    return [self then:resultContinuation unless:nil];
}

-(TOCFuture *)catch:(TOCFutureCatchContinuation)failureContinuation {
    return [self catch:failureContinuation unless:nil];
}

-(TOCFuture*) unless:(TOCCancelToken*)unlessCancelledToken {
    // optimistically do nothing, when given immortal cancel tokens
    if (unlessCancelledToken.state == TOCCancelTokenState_Immortal) {
        return self;
    }
    
    return [self finally:^(TOCFuture *completed) { return completed; }
                  unless:unlessCancelledToken];
}

@end
