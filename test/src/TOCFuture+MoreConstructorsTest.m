#import <SenTestingKit/SenTestingKit.h>

#import "TOCFuture+MoreContructors.h"
#import "TOCFuture+MoreContinuations.h"
#import "TestUtil.h"

@interface TOCFutureExtraTest : SenTestCase
@end

@implementation TOCFutureExtraTest {
@private NSThread* thread;
@private NSRunLoop* runLoop;
}

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

-(void)testFutureWithCancelFailure {
    test([[TOCFuture futureWithCancelFailure] hasFailedWithCancel]);
    test([[TOCFuture futureWithCancelFailure].forceGetFailure isKindOfClass:[TOCCancelToken class]]);
}
-(void)testFutureWithTimeoutFailure {
    test([[TOCFuture futureWithTimeoutFailure] hasFailedWithTimeout]);
    test([[TOCFuture futureWithTimeoutFailure].forceGetFailure isKindOfClass:[TOCTimeout class]]);
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
    
    // churn run loop so timer can complete
    for (int i = 0; i < 5 && f.isIncomplete; i++) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    
    testCompletesConcurrently(f);
    testFutureHasResult(f, @1);
}
-(void)testFutureWithResultAfterDelay_NotCompleted {
    testThrows([TOCFuture futureWithResult:@"X" afterDelay:-1]);
    testThrows([TOCFuture futureWithResult:@"X" afterDelay:-INFINITY]);
    testThrows([TOCFuture futureWithResult:@"X" afterDelay:NAN]);
    testFutureHasResult([TOCFuture futureWithResult:@"X" afterDelay:0], @"X");
    testDoesNotCompleteConcurrently([TOCFuture futureWithResult:@"X" afterDelay:INFINITY]);
    
    TOCFuture* f = [TOCFuture futureWithResult:@1
                                    afterDelay:100.0];
    
    // churn run loop so timer can complete
    for (int i = 0; i < 5 && f.isIncomplete; i++) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    
    test(f.isIncomplete);
}

-(void)testHasFailedWithCancel {
    test(![TOCFutureSource new].future.hasFailedWithCancel);
    test(![TOCFuture futureWithResult:@0].hasFailedWithCancel);
    test(![TOCFuture futureWithResult:TOCCancelToken.cancelledToken].hasFailedWithCancel);
    test(![TOCFuture futureWithFailure:@0].hasFailedWithCancel);
    
    test([TOCFuture futureWithFailure:TOCCancelToken.cancelledToken].hasFailedWithCancel);
}

-(void) testFutureWithResultFromAsyncOperationWithResultLastingUntilCancelled_Immediate {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCAsyncOperationWithResultLastingUntilCancelled t = ^(TOCCancelToken* until) { return s.future; };
    
    testThrows([TOCFuture futureWithResultFromAsyncOperationWithResultLastingUntilCancelled:nil
                                                                       withOperationTimeout:0
                                                                                      until:nil]);
    testThrows([TOCFuture futureWithResultFromAsyncOperationWithResultLastingUntilCancelled:t
                                                                       withOperationTimeout:NAN
                                                                                      until:nil]);
    testThrows([TOCFuture futureWithResultFromAsyncOperationWithResultLastingUntilCancelled:t
                                                                       withOperationTimeout:-1
                                                                                      until:nil]);
    test([[TOCFuture futureWithResultFromAsyncOperationWithResultLastingUntilCancelled:t
                                                                  withOperationTimeout:0
                                                                                 until:nil] hasFailedWithTimeout]);
    test([[TOCFuture futureWithResultFromAsyncOperationWithResultLastingUntilCancelled:t
                                                                  withOperationTimeout:1000
                                                                                 until:TOCCancelToken.cancelledToken] hasFailedWithCancel]);
    testFutureHasResult([TOCFuture futureWithResultFromAsyncOperationWithResultLastingUntilCancelled:^(TOCCancelToken* _){ return [TOCFuture futureWithResult:@1]; }
                                                                                withOperationTimeout:1000
                                                                                               until:nil], @1);
    testFutureHasFailure([TOCFuture futureWithResultFromAsyncOperationWithResultLastingUntilCancelled:^(TOCCancelToken* _){ return [TOCFuture futureWithFailure:@2]; }
                                                                                withOperationTimeout:1000
                                                                                               until:nil], @2);
}
-(void) testFutureWithResultFromAsyncOperationWithResultLastingUntilCancelled_Timeout {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCAsyncOperationWithResultLastingUntilCancelled t = ^(TOCCancelToken* until) { return s.future; };
    
    TOCFuture* f0 = [TOCFuture futureWithResultFromAsyncOperationWithResultLastingUntilCancelled:t
                                                                            withOperationTimeout:0.01
                                                                                           until:nil];
    TOCFuture* f1 = [TOCFuture futureWithResultFromAsyncOperationWithResultLastingUntilCancelled:t
                                                                            withOperationTimeout:0.05
                                                                                           until:nil];
    TOCFuture* f2 = [TOCFuture futureWithResultFromAsyncOperationWithResultLastingUntilCancelled:t
                                                                            withOperationTimeout:100.0
                                                                                           until:nil];
    
    // churn run loop so timer can complete
    for (int i = 0; i < 5 && f2.isIncomplete; i++) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }

    test(f0.hasFailedWithTimeout);
    test(f1.hasFailedWithTimeout);
    test(f2.isIncomplete);
    [s trySetResult:@1];
    testFutureHasResult(f2, @1);
}
-(void) testFutureWithResultFromAsyncOperationWithResultLastingUntilCancelled_CancelDuring {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCAsyncOperationWithResultLastingUntilCancelled t = ^(TOCCancelToken* until) { [until whenCancelledTryCancelFutureSource:s]; return [TOCFutureSource new].future; };

    TOCCancelTokenSource* c = [TOCCancelTokenSource new];
    TOCFuture* f = [TOCFuture futureWithResultFromAsyncOperationWithResultLastingUntilCancelled:t
                                                                            withOperationTimeout:100.0
                                                                                           until:c.token];
    test(f.isIncomplete);
    [c cancel];
    test(s.future.hasFailedWithCancel);
    test(f.hasFailedWithCancel);
}
-(void) testFutureWithResultFromAsyncOperationWithResultLastingUntilCancelled_CancelAfter {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCCancelTokenSource* d = [TOCCancelTokenSource new];
    TOCAsyncOperationWithResultLastingUntilCancelled t = ^(TOCCancelToken* until) { [until whenCancelledCancelSource:d]; return s.future; };
    
    TOCCancelTokenSource* c = [TOCCancelTokenSource new];
    TOCFuture* f = [TOCFuture futureWithResultFromAsyncOperationWithResultLastingUntilCancelled:t
                                                                           withOperationTimeout:100.0
                                                                                          until:c.token];
    test(f.isIncomplete);
    [s forceSetResult:d];
    testFutureHasResult(f, d);
    test(!d.token.isAlreadyCancelled);
    [c cancel];
    test(d.token.isAlreadyCancelled);
}

-(void) testFutureWithResultFromAsyncCancellableOperationWithTimeout_Immediate {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCAsyncCancellableOperation t = ^(TOCCancelToken* unless) { return s.future; };
    
    testThrows([TOCFuture futureWithResultFromAsyncCancellableOperation:nil
                                                            withTimeout:100]);
    testThrows([TOCFuture futureWithResultFromAsyncCancellableOperation:t
                                                            withTimeout:-1]);
    testThrows([TOCFuture futureWithResultFromAsyncCancellableOperation:t
                                                            withTimeout:NAN]);
    test([[TOCFuture futureWithResultFromAsyncCancellableOperation:t
                                                       withTimeout:0] hasFailedWithTimeout]);
    testFutureHasResult([TOCFuture futureWithResultFromAsyncCancellableOperation:^(TOCCancelToken* _){ return [TOCFuture futureWithResult:@1]; }
                                                                     withTimeout:100], @1);
    testFutureHasFailure([TOCFuture futureWithResultFromAsyncCancellableOperation:^(TOCCancelToken* _){ return [TOCFuture futureWithFailure:@2]; }
                                                                      withTimeout:100], @2);
}
-(void) testFutureWithResultFromAsyncCancellableOperationWithTimeout_WaitsForCancel {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCAsyncCancellableOperation t = ^(TOCCancelToken* unless) { return s.future; };
    TOCCancelTokenSource* c = [TOCCancelTokenSource new];
    TOCFuture* f = [TOCFuture futureWithResultFromAsyncCancellableOperation:t
                                                                withTimeout:0.0001];
    
    // churn run loop so timer can complete
    for (int i = 0; i < 5; i++) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }

    [c cancel];
    test(f.isIncomplete);
    [s trySetFailedWithCancel];
    test(f.hasFailedWithTimeout);
}
-(void) testFutureWithResultFromAsyncCancellableOperationWithTimeoutWaitsForResult {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCAsyncCancellableOperation t = ^(TOCCancelToken* unless) { return s.future; };
    TOCCancelTokenSource* c = [TOCCancelTokenSource new];
    TOCFuture* f = [TOCFuture futureWithResultFromAsyncCancellableOperation:t
                                                                withTimeout:0.0001];
    
    // churn run loop so timer can complete
    for (int i = 0; i < 5; i++) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }

    [c cancel];
    test(f.isIncomplete);
    [s trySetResult:@1];
    testFutureHasResult(f, @1);
}
-(void) testFutureWithResultFromAsyncCancellableOperationWithTimeout_WaitsForFailure {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCAsyncCancellableOperation t = ^(TOCCancelToken* unless) { return s.future; };
    TOCCancelTokenSource* c = [TOCCancelTokenSource new];
    TOCFuture* f = [TOCFuture futureWithResultFromAsyncCancellableOperation:t
                                                                withTimeout:0.0001];
    // churn run loop so timer can complete
    for (int i = 0; i < 5; i++) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    
    [c cancel];
    test(f.isIncomplete);
    [s trySetFailure:@2];
    testFutureHasFailure(f, @2);
}
-(void) testFutureWithResultFromAsyncCancellableOperationWithTimeout_Timeout {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCAsyncCancellableOperation t = ^(TOCCancelToken* unless) { return [s.future unless:unless]; };
    
    TOCFuture* f0 = [TOCFuture futureWithResultFromAsyncCancellableOperation:t
                                                                 withTimeout:0.01];
    TOCFuture* f1 = [TOCFuture futureWithResultFromAsyncCancellableOperation:t
                                                                 withTimeout:0.05];
    TOCFuture* f2 = [TOCFuture futureWithResultFromAsyncCancellableOperation:t
                                                                 withTimeout:100.0];
    
    // churn run loop so timer can complete
    for (int i = 0; i < 5 && f2.isIncomplete; i++) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    
    test(f0.hasFailedWithTimeout);
    test(f1.hasFailedWithTimeout);
    test(f2.isIncomplete);
    [s trySetResult:@1];
    testFutureHasResult(f2, @1);
}

-(void) testFutureWithResultFromAsyncCancellableOperationWithTimeoutUnless_Immediate {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCAsyncCancellableOperation t = ^(TOCCancelToken* unless) { return [s.future unless:unless]; };
    
    testThrows([TOCFuture futureWithResultFromAsyncCancellableOperation:nil
                                                            withTimeout:100
                                                                 unless:nil]);
    testThrows([TOCFuture futureWithResultFromAsyncCancellableOperation:t
                                                            withTimeout:-1
                                                                 unless:nil]);
    testThrows([TOCFuture futureWithResultFromAsyncCancellableOperation:t
                                                            withTimeout:NAN
                                                                 unless:nil]);
    test([[TOCFuture futureWithResultFromAsyncCancellableOperation:t
                                                       withTimeout:0
                                                            unless:nil] hasFailedWithTimeout]);
    test([[TOCFuture futureWithResultFromAsyncCancellableOperation:t
                                                       withTimeout:100
                                                            unless:TOCCancelToken.cancelledToken] hasFailedWithCancel]);
    testFutureHasResult([TOCFuture futureWithResultFromAsyncCancellableOperation:^(TOCCancelToken* _){ return [TOCFuture futureWithResult:@1]; }
                                                                     withTimeout:100
                                                                          unless:nil], @1);
    testFutureHasFailure([TOCFuture futureWithResultFromAsyncCancellableOperation:^(TOCCancelToken* _){ return [TOCFuture futureWithFailure:@2]; }
                                                                      withTimeout:100
                                                                           unless:nil], @2);
}
-(void) testFutureWithResultFromAsyncCancellableOperationWithTimeoutUnless_WaitsForTimeoutCancel {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCAsyncCancellableOperation t = ^(TOCCancelToken* unless) { return s.future; };
    TOCCancelTokenSource* c = [TOCCancelTokenSource new];
    TOCFuture* f = [TOCFuture futureWithResultFromAsyncCancellableOperation:t
                                                                withTimeout:0.0001
                                                                     unless:c.token];

    // churn run loop so timer can complete
    for (int i = 0; i < 5; i++) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }

    test(f.isIncomplete);
    [s trySetFailedWithCancel];
    test(f.hasFailedWithTimeout);
}
-(void) testFutureWithResultFromAsyncCancellableOperationWithTimeoutUnless_WaitsForCancel {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCAsyncCancellableOperation t = ^(TOCCancelToken* unless) { return s.future; };
    TOCCancelTokenSource* c = [TOCCancelTokenSource new];
    TOCFuture* f = [TOCFuture futureWithResultFromAsyncCancellableOperation:t
                                                                withTimeout:10000.0
                                                                     unless:c.token];
    [c cancel];
    test(f.isIncomplete);
    [s trySetFailedWithCancel];
    test(f.hasFailedWithCancel);
}
-(void) testFutureWithResultFromAsyncCancellableOperationWithTimeoutUnless_WaitsForResult {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCAsyncCancellableOperation t = ^(TOCCancelToken* unless) { return s.future; };
    TOCCancelTokenSource* c = [TOCCancelTokenSource new];
    TOCFuture* f = [TOCFuture futureWithResultFromAsyncCancellableOperation:t
                                                                withTimeout:10000.0
                                                                     unless:c.token];
    [c cancel];
    test(f.isIncomplete);
    [s trySetResult:@1];
    testFutureHasResult(f, @1);
}
-(void) testFutureWithResultFromAsyncCancellableOperationWithTimeoutUnless_WaitsForFailure {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCAsyncCancellableOperation t = ^(TOCCancelToken* unless) { return s.future; };
    TOCCancelTokenSource* c = [TOCCancelTokenSource new];
    TOCFuture* f = [TOCFuture futureWithResultFromAsyncCancellableOperation:t
                                                                withTimeout:10000.0
                                                                     unless:c.token];
    [c cancel];
    test(f.isIncomplete);
    [s trySetFailure:@2];
    testFutureHasFailure(f, @2);
}
-(void) testFutureWithResultFromAsyncCancellableOperationWithTimeoutUnless_Timeout {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCAsyncCancellableOperation t = ^(TOCCancelToken* unless) { return [s.future unless:unless]; };
    
    TOCFuture* f0 = [TOCFuture futureWithResultFromAsyncCancellableOperation:t
                                                                 withTimeout:0.01
                                                                      unless:nil];
    TOCFuture* f1 = [TOCFuture futureWithResultFromAsyncCancellableOperation:t
                                                                 withTimeout:0.05
                                                                      unless:nil];
    TOCFuture* f2 = [TOCFuture futureWithResultFromAsyncCancellableOperation:t
                                                                 withTimeout:100.0
                                                                      unless:nil];
    
    // churn run loop so timer can complete
    for (int i = 0; i < 5 && f2.isIncomplete; i++) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    
    test(f0.hasFailedWithTimeout);
    test(f1.hasFailedWithTimeout);
    test(f2.isIncomplete);
    [s trySetResult:@1];
    testFutureHasResult(f2, @1);
}
-(void) testFutureWithResultFromAsyncCancellableOperationWithTimeoutUnless_CancelDuring {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCAsyncCancellableOperation t = ^(TOCCancelToken* unless) { [unless whenCancelledTryCancelFutureSource:s]; return s.future; };
    
    TOCCancelTokenSource* c = [TOCCancelTokenSource new];
    TOCFuture* f = [TOCFuture futureWithResultFromAsyncCancellableOperation:t
                                                                withTimeout:100.0
                                                                     unless:c.token];
    test(f.isIncomplete);
    [c cancel];
    test(s.future.hasFailedWithCancel);
    test(f.hasFailedWithCancel);
}

@end
