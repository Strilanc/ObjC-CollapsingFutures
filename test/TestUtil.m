#import "TestUtil.h"

int testTargetHits = 0;

bool testPassesConcurrently_helper(bool (^check)(void), NSTimeInterval delay) {
    NSTimeInterval t = [[NSProcessInfo processInfo] systemUptime] + delay;
    while ([[NSProcessInfo processInfo] systemUptime] < t && !check()) {
    }
    return check();
}
bool testCompletesConcurrently_helper(TOCFuture* future, NSTimeInterval delay) {
    return testPassesConcurrently_helper(^bool{ return ![future isIncomplete]; }, delay);
}

@implementation DeallocCounter
@synthesize helperDeallocCount;
-(DeallocCounterHelper*) makeInstanceToCount {
    return [DeallocCounterHelper helper:self];
}
@end

@implementation DeallocCounterHelper {
@private DeallocCounter* parent;
}
+(DeallocCounterHelper*) helper:(DeallocCounter*)parent {
    DeallocCounterHelper* helper = [DeallocCounterHelper new];
    helper->parent = parent;
    return helper;
}
-(void) dealloc {
    parent.helperDeallocCount += 1;
}
-(void) poke {
    // tee hee!
}
@end
