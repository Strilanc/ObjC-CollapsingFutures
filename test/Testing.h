#import <SenTestingKit/SenTestingKit.h>
#import <Foundation/Foundation.h>
#import "TOCFutureAndSource.h"
#import <mach/mach.h>

vm_size_t peekAllocatedMemoryInBytes(void);
bool testPassesConcurrently_helper(bool (^check)(void), NSTimeInterval delay);
bool testCompletesConcurrently_helper(TOCFuture* future, NSTimeInterval timeout);
bool futureHasResult(TOCFuture* future, id result);
bool futureHasFailure(TOCFuture* future, id failure);
int testTargetHits;

#define test(expressionExpectedToBeTrue) STAssertTrue(expressionExpectedToBeTrue, @"")
#define testThrows(expressionExpectedToThrow) STAssertThrows(expressionExpectedToThrow, @"")
#define testCompletesConcurrently(future) test(testCompletesConcurrently_helper(future, 2.0))
#define testDoesNotCompleteConcurrently(future) test(!testCompletesConcurrently_helper(future, 0.01))
#define testUntil(condition) test(testPassesConcurrently_helper(^bool{ return (condition);}, 2.0))
#define testChurnUntil(condition) \
    for (int _churnCounter_xxx = 0; _churnCounter_xxx < 5 && !(condition); _churnCounter_xxx++) { \
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]]; \
    } \
    test(condition)

#define testHitsTarget(expression) testTargetHits = 0; \
                                   expression; \
                                   test(testTargetHits == 1)
#define testDoesNotHitTarget(expression) testTargetHits = 0; \
                                         expression; \
                                         test(testTargetHits == 0)
#define hitTarget (testTargetHits++)

#define testFutureHasResult(future, result) test(futureHasResult(future, result))
#define testFutureHasFailure(future, failure) test(futureHasFailure(future, failure))

#define fut(X) [TOCFuture futureWithResult:X]
#define futfail(X) [TOCFuture futureWithFailure:X]

@class DeallocToken;
@interface DeallocCounter : NSObject
@property (atomic) NSUInteger lostTokenCount;
-(DeallocToken*) makeToken;
@end
@interface DeallocToken : NSObject
+(DeallocToken*) token:(DeallocCounter*)parent;
-(void) poke;
@end
