#import <Foundation/Foundation.h>
#import "Future.h"

bool testCompletesConcurrently_helper(Future* future, NSTimeInterval timeout);
int testTargetHits;

#define test(expressionExpectedToBeTrue) STAssertTrue(expressionExpectedToBeTrue, @"")
#define testThrows(expressionExpectedToThrow) STAssertThrows(expressionExpectedToThrow, @"")
#define testCompletesConcurrently(future) test(testCompletesConcurrently_helper(future, 5.0))
#define testDoesNotCompleteConcurrently(future) test(!testCompletesConcurrently_helper(future, 0.01))
#define testHitsTarget(expression) testTargetHits = 0; \
                                   expression; \
                                   test(testTargetHits == 1)
#define testDoesNotHitTarget(expression) testTargetHits = 0; \
                                         expression; \
                                         test(testTargetHits == 0)
#define hitTarget (testTargetHits++)

#define testFutureHasResult(future, result) test([future hasResult] && [[future forceGetResult] isEqual:result])
#define testFutureHasFailure(future, failure) test([future hasFailed] && [[future forceGetFailure] isEqual:failure])
