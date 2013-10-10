#import "TestUtil.h"

int testTargetHits = 0;

bool testCompletesConcurrently_helper(Future* future, NSTimeInterval delay) {
    NSTimeInterval t = [[NSProcessInfo processInfo] systemUptime] + delay;
    while ([[NSProcessInfo processInfo] systemUptime] < t && [future isIncomplete]) {
    }
    return ![future isIncomplete];
}
