#import <SenTestingKit/SenTestingKit.h>

#import "TOCFutureExtra.h"
#import "TestUtil.h"

@interface TOCFutureExtraTest : SenTestCase {
@private NSThread* thread;
@private NSRunLoop* runLoop;
}

@end

@implementation TOCFutureExtraTest

-(void) setUp {
    thread = [[NSThread alloc] initWithTarget:self selector:@selector(runLoopUntilCancelled) object:nil];
    [thread start];
    
    while (true) {
        @synchronized(self) {
            if (runLoop != nil) break;
        }
    }
}
-(void) runLoopUntilCancelled {
    NSThread* curThread = [NSThread currentThread];
    NSRunLoop* curRunLoop = [NSRunLoop currentRunLoop];
    @synchronized(self) {
        runLoop = curRunLoop;
    }
    while (![curThread isCancelled]) {
        [curRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
}
-(void) tearDown {
    [thread cancel];
}

-(void)testTOCFutureWithResultFromOperationOnThread {
    TOCFuture* f = [TOCFuture futureWithResultFromOperation:^{ return @1; }
                                      invokedOnThread:thread];
    testCompletesConcurrently(f);
    testTOCFutureHasResult(f, @1);
}
-(void)testTOCFutureWithResultFromOperationDispatch {
    TOCFuture* f = [TOCFuture futureWithResultFromOperation:^{ return @1; }
                                    dispatchedOnQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    testCompletesConcurrently(f);
    testTOCFutureHasResult(f, @1);
}
-(void)testTOCFutureWithResultAfterDelay {
    testThrows([TOCFuture futureWithResult:@"X" afterDelay:-1]);
    testThrows([TOCFuture futureWithResult:@"X" afterDelay:-INFINITY]);
    testThrows([TOCFuture futureWithResult:@"X" afterDelay:NAN]);
    testTOCFutureHasResult([TOCFuture futureWithResult:@"X" afterDelay:0], @"X");
    testDoesNotCompleteConcurrently([TOCFuture futureWithResult:@"X" afterDelay:INFINITY]);
    
    TOCFuture* f = [TOCFuture futureWithResult:@1
                              afterDelay:0.1];
    testCompletesConcurrently(f);
    testTOCFutureHasResult(f, @1);
}
-(void)testOrderedByCompletion {
    test([[TOCFuture orderedByCompletion:@[]] isEqual:@[]]);
    testThrows([TOCFuture orderedByCompletion:nil]);
    testThrows([TOCFuture orderedByCompletion:(@[@1])]);
    
    NSArray* f = (@[[TOCFutureSource new], [TOCFutureSource new], [TOCFutureSource new]]);
    NSArray* g = [TOCFuture orderedByCompletion:f];
    test([g count] == [f count]);
    
    test([[g objectAtIndex:0] isIncomplete]);
    
    [[f objectAtIndex:1] trySetResult:@"A"];
    testTOCFutureHasResult([g objectAtIndex:0], @"A");
    test([[g objectAtIndex:1] isIncomplete]);
    
    [[f objectAtIndex:2] trySetFailure:@"B"];
    testTOCFutureHasFailure([g objectAtIndex:1], @"B");
    test([[g objectAtIndex:2] isIncomplete]);
    
    [[f objectAtIndex:0] trySetResult:@"C"];
    testTOCFutureHasResult([g objectAtIndex:2], @"C");
    
    // ordered by continuations, so after completion should preserve ordering
    NSArray* g2 = [TOCFuture orderedByCompletion:f];
    testTOCFutureHasResult([g2 objectAtIndex:0], @"C");
    testTOCFutureHasResult([g2 objectAtIndex:1], @"A");
    testTOCFutureHasFailure([g2 objectAtIndex:2], @"B");
}

@end
