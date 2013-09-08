#import "FutureExtraTest.h"
#import "FutureExtra.h"
#import "TestUtil.h"

@implementation FutureExtraTest

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

-(void)testFutureWithResultFromOperationOnThread {
    Future* f = [Future futureWithResultFromOperation:^{ return @1; }
                                      invokedOnThread:thread];
    testCompletesConcurrently(f);
    testFutureHasResult(f, @1);
}
-(void)testFutureWithResultFromOperationDispatch {
    Future* f = [Future futureWithResultFromOperation:^{ return @1; }
                                    dispatchedOnQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    testCompletesConcurrently(f);
    testFutureHasResult(f, @1);
}
-(void)testFutureWithResultAfterDelay {
    testThrows([Future futureWithResult:@"X" afterDelay:-1]);
    testThrows([Future futureWithResult:@"X" afterDelay:-INFINITY]);
    testThrows([Future futureWithResult:@"X" afterDelay:NAN]);
    testFutureHasResult([Future futureWithResult:@"X" afterDelay:0], @"X");
    testDoesNotCompleteConcurrently([Future futureWithResult:@"X" afterDelay:INFINITY]);
    
    Future* f = [Future futureWithResult:@1
                              afterDelay:0.1];
    testCompletesConcurrently(f);
    testFutureHasResult(f, @1);
}
-(void)testOrderedByCompletion {
    test([[Future orderedByCompletion:@[]] isEqual:@[]]);
    testThrows([Future orderedByCompletion:nil]);
    testThrows([Future orderedByCompletion:(@[@1])]);
    
    NSArray* f = (@[[FutureSource new], [FutureSource new], [FutureSource new]]);
    NSArray* g = [Future orderedByCompletion:f];
    test([g count] == [f count]);
    
    test([[g objectAtIndex:0] isIncomplete]);
    
    [[f objectAtIndex:1] trySetResult:@"A"];
    testFutureHasResult([g objectAtIndex:0], @"A");
    test([[g objectAtIndex:1] isIncomplete]);
    
    [[f objectAtIndex:2] trySetFailure:@"B"];
    testFutureHasFailure([g objectAtIndex:1], @"B");
    test([[g objectAtIndex:2] isIncomplete]);
    
    [[f objectAtIndex:0] trySetResult:@"C"];
    testFutureHasResult([g objectAtIndex:2], @"C");
    
    // ordered by continuations, so after completion should preserve ordering
    NSArray* g2 = [Future orderedByCompletion:f];
    testFutureHasResult([g2 objectAtIndex:0], @"C");
    testFutureHasResult([g2 objectAtIndex:1], @"A");
    testFutureHasFailure([g2 objectAtIndex:2], @"B");
}

@end
