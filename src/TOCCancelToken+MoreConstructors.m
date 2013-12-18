#import "TOCCancelToken+MoreConstructors.h"
#import "TOCInternal.h"

@implementation TOCCancelToken (MoreConstructors)

+(TOCCancelToken*) matchFirstToCancelBetween:(TOCCancelToken*)token1 and:(TOCCancelToken*)token2 {
    // check for special cases where we can just give back one of the tokens
    if (token1 == token2) return token1;
    enum TOCCancelTokenState state1 = token1.state;
    enum TOCCancelTokenState state2 = token2.state;
    if (state1 == TOCCancelTokenState_Cancelled) return token1;
    if (state2 == TOCCancelTokenState_Immortal) return token1;
    if (state1 == TOCCancelTokenState_Immortal) return token2;
    if (state2 == TOCCancelTokenState_Cancelled) return token2;
    
    TOCCancelTokenSource* minSource = [TOCCancelTokenSource new];
    void (^doCancel)(void) = [^{ [minSource cancel]; } copy];
    [token1 whenCancelledDo:doCancel unless:minSource.token];
    [token2 whenCancelledDo:doCancel unless:minSource.token];
    return minSource.token;
}

+(TOCCancelToken*) matchLastToCancelBetween:(TOCCancelToken*)token1 and:(TOCCancelToken*)token2 {
    // check for special cases where we can just give back one of the tokens
    if (token1 == token2) return token1;
    enum TOCCancelTokenState state1 = token1.state;
    enum TOCCancelTokenState state2 = token2.state;
    if (state1 == TOCCancelTokenState_Immortal) return token1;
    if (state2 == TOCCancelTokenState_Cancelled) return token1;
    if (state1 == TOCCancelTokenState_Cancelled) return token2;
    if (state2 == TOCCancelTokenState_Immortal) return token2;
    
    // make a token source that will be cancelled when either of the input tokens goes immortal or is cancelled
    TOCCancelTokenSource* cancelledWhenEitherSettle = [TOCCancelTokenSource new];
    void (^didSettle)(void) = [^{ [cancelledWhenEitherSettle cancel]; } copy];
    TOCInternal_OnDeallocObject* onDealloc1 = [TOCInternal_OnDeallocObject onDeallocDo:didSettle];
    TOCInternal_OnDeallocObject* onDealloc2 = [TOCInternal_OnDeallocObject onDeallocDo:didSettle];
    [token1 whenCancelledDo:^{ [onDealloc1 poke]; [cancelledWhenEitherSettle cancel]; }
                     unless:cancelledWhenEitherSettle.token];
    [token2 whenCancelledDo:^{ [onDealloc2 poke]; [cancelledWhenEitherSettle cancel]; }
                     unless:cancelledWhenEitherSettle.token];
    
    // work to cancel the result can continue once one of the input tokens has settled
    TOCCancelTokenSource* maxSource = [TOCCancelTokenSource new];
    [cancelledWhenEitherSettle.token whenCancelledDo:^{
        enum TOCCancelTokenState settledState1 = token1.state;
        enum TOCCancelTokenState settledState2 = token2.state;
        
        // if either token is immortal, we can just return (resulting in the last ref to maxSource being lost and it going immortal)
        if (settledState1 == TOCCancelTokenState_Immortal) return;
        if (settledState2 == TOCCancelTokenState_Immortal) return;
        
        // avoid the token that's been cancelled, so we condition on the only one that can be alive
        TOCCancelToken* remainingToken = settledState1 == TOCCancelTokenState_Cancelled ? token2 : token1;
        [remainingToken whenCancelledDo:^{
            [maxSource cancel];
        }];
    }];
    return maxSource.token;
}

@end
