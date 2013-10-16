#import "TestUtil.h"

int testTargetHits = 0;

bool futureHasResult(TOCFuture* future, id result) {
    return future.hasResult && [future.forceGetResult isEqual:result];
}
bool futureHasFailure(TOCFuture* future, id failure) {
    return future.hasFailed && [future.forceGetFailure isEqual:failure];
}
bool testPassesConcurrently_helper(bool (^check)(void), NSTimeInterval delay) {
    NSTimeInterval t = [[NSProcessInfo processInfo] systemUptime] + delay;
    while ([[NSProcessInfo processInfo] systemUptime] < t && !check()) {
    }
    return check();
}
bool testCompletesConcurrently_helper(TOCFuture* future, NSTimeInterval delay) {
    return testPassesConcurrently_helper(^bool{ return !future.isIncomplete; }, delay);
}

@implementation DeallocCounter
@synthesize lostTokenCount;
-(DeallocToken*) makeToken {
    return [DeallocToken token:self];
}
@end

@implementation DeallocToken {
@private DeallocCounter* parent;
}
+(DeallocToken*) token:(DeallocCounter*)parent {
    DeallocToken* token = [DeallocToken new];
    token->parent = parent;
    return token;
}
-(void) dealloc {
    parent.lostTokenCount += 1;
}
-(void) poke {
    // tee hee!
}
@end
