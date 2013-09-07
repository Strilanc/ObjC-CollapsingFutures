#import <Foundation/Foundation.h>
#import "Future.h"

bool testCompletesConcurrently_helper(Future* future, NSTimeInterval timeout);

#define test(expressionExpectedToBeTrue) STAssertTrue(expressionExpectedToBeTrue, @"")
#define testThrows(expressionExpectedToThrow) STAssertThrows(expressionExpectedToThrow, @"")
#define testCompletesConcurrently(future) test(testCompletesConcurrently_helper(future, 5.0))
#define testDoesNotCompleteConcurrently(future) test(!testCompletesConcurrently_helper(future, 0.01))
