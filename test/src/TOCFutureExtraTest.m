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

-(void)testFutureWithResultFromOperationOnThread {
    TOCFuture* f = [TOCFuture futureWithResultFromOperation:^{ return @1; }
                                      invokedOnThread:thread];
    testCompletesConcurrently(f);
    testFutureHasResult(f, @1);
}
-(void)testFutureWithResultFromOperationDispatch {
    TOCFuture* f = [TOCFuture futureWithResultFromOperation:^{ return @1; }
                                    dispatchedOnQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    testCompletesConcurrently(f);
    testFutureHasResult(f, @1);
}
-(void)testFutureWithResultAfterDelay {
    testThrows([TOCFuture futureWithResult:@"X" afterDelay:-1]);
    testThrows([TOCFuture futureWithResult:@"X" afterDelay:-INFINITY]);
    testThrows([TOCFuture futureWithResult:@"X" afterDelay:NAN]);
    testFutureHasResult([TOCFuture futureWithResult:@"X" afterDelay:0], @"X");
    testDoesNotCompleteConcurrently([TOCFuture futureWithResult:@"X" afterDelay:INFINITY]);
    
    TOCFuture* f = [TOCFuture futureWithResult:@1
                              afterDelay:0.1];
    testCompletesConcurrently(f);
    testFutureHasResult(f, @1);
}

@end
