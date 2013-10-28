#import "TestUtil.h"

int testTargetHits = 0;

vm_size_t peekAllocatedMemoryInBytes(void) {
    struct task_basic_info info;
    mach_msg_type_number_t size = sizeof(info);
    kern_return_t kerr = task_info(mach_task_self(),
                                   TASK_BASIC_INFO,
                                   (task_info_t)&info,
                                   &size);
    assert(kerr == KERN_SUCCESS);
    return info.resident_size;
}
bool futureHasResult(TOCFuture* future, id result) {
    return future.hasResult && (result == future.forceGetResult || [future.forceGetResult isEqual:result]);
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
