#import <SenTestingKit/SenTestingKit.h>
#import "Array+TOCFuture.h"
#import "TestUtil.h"

@interface TOCFutureArrayUtilTest : SenTestCase
@end

@implementation TOCFutureArrayUtilTest

-(void)testOrderedByCompletion {
    test([[@[] asyncOrderedByCompletion] isEqual:@[]]);
    testThrows([(@[@1]) asyncOrderedByCompletion]);
    
    NSArray* s = (@[[TOCFutureSource new], [TOCFutureSource new], [TOCFutureSource new]]);
    NSArray* f = (@[[s[0] future], [s[1] future], [s[2] future]]);
    NSArray* g = [f asyncOrderedByCompletion];
    test(g.count == f.count);
    
    test(((TOCFuture*)g[0]).isIncomplete);
    
    [s[1] trySetResult:@"A"];
    testFutureHasResult(g[0], @"A");
    test(((TOCFuture*)g[1]).isIncomplete);
    
    [s[2] trySetFailure:@"B"];
    testFutureHasFailure(g[1], @"B");
    test(((TOCFuture*)g[2]).isIncomplete);
    
    [s[0] trySetResult:@"C"];
    testFutureHasResult(g[2], @"C");
    
    // ordered by continuations, so after completion should preserve ordering of original array
    NSArray* g2 = [f asyncOrderedByCompletion];
    testFutureHasResult(g2[0], @"C");
    testFutureHasResult(g2[1], @"A");
    testFutureHasFailure(g2[2], @"B");
}
-(void) testFinallyAll {
    testThrows([@[@1] asyncFinallyAll]);
    test([[@[] asyncFinallyAll].forceGetResult isEqual:@[]]);
    
    TOCFuture* f = [(@[fut(@1), futfail(@2)]) asyncFinallyAll];
    test(f.hasResult);
    NSArray* x = f.forceGetResult;
    test(x.count == 2);
    testFutureHasResult(x[0], @1);
    testFutureHasFailure(x[1], @2);
}
-(void) testFinallyAll_Incomplete {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCFuture* f = [(@[fut(@1), s.future, fut(@3)]) asyncFinallyAll];
    test(f.isIncomplete);
    
    [s trySetFailure:@""];
    test(f.hasResult);
    NSArray* x = f.forceGetResult;
    test(x.count == 3);
    testFutureHasResult(x[0], @1);
    testFutureHasFailure(x[1], @"");
    testFutureHasResult(x[2], @3);
}
-(void) testThenAll {
    testThrows([@[@1] asyncThenAll]);
    test([[@[] asyncThenAll].forceGetResult isEqual:@[]]);
    test([[(@[fut(@3)]) asyncThenAll].forceGetResult isEqual:(@[@3])]);
    test([[(@[fut(@1), fut(@2)]) asyncThenAll].forceGetResult isEqual:(@[@1, @2])]);
    
    TOCFuture* f = [(@[fut(@1), futfail(@2)]) asyncThenAll];
    test(f.hasFailed);
    NSArray* x = f.forceGetFailure;
    test(x.count == 2);
    testFutureHasResult(x[0], @1);
    testFutureHasFailure(x[1], @2);
}
-(void) testThenAll_Incomplete {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCFuture* f = [(@[fut(@1), s.future, fut(@3)]) asyncThenAll];
    test(f.isIncomplete);
    [s trySetResult:@""];
    testFutureHasResult(f, (@[@1, @"", @3]));
}
-(void) testAsyncRaceAsynchronousResultUntilCancelledOperationsUntil_Failures {
    testThrows([@[] asyncRaceOperationsWithWinnerLastingUntil:nil]);
    testThrows([@[@1] asyncRaceOperationsWithWinnerLastingUntil:nil]);
    testThrows([(@[[TOCFuture futureWithResult:@1]]) asyncRaceOperationsWithWinnerLastingUntil:nil]);
}
-(void) testAsyncRaceAsynchronousResultUntilCancelledOperationsUntil_Immediate {
    TOCAsyncOperationWithResultLastingUntilCancelled immediate1 = ^(TOCCancelToken* until) {
        hitTarget;
        test(until != nil);
        return [TOCFuture futureWithResult:@1];
    };
    TOCAsyncOperationWithResultLastingUntilCancelled immediateFail = ^(TOCCancelToken* until) {
        test(until != nil);
        return [TOCFuture futureWithFailure:@"bleh"];
    };
    
    testHitsTarget([@[immediate1] asyncRaceOperationsWithWinnerLastingUntil:nil]);
    testFutureHasResult([@[immediate1] asyncRaceOperationsWithWinnerLastingUntil:nil], @1);
    testFutureHasResult([(@[immediate1, immediateFail]) asyncRaceOperationsWithWinnerLastingUntil:nil], @1);
    testFutureHasResult([(@[immediateFail, immediate1]) asyncRaceOperationsWithWinnerLastingUntil:nil], @1);
    testFutureHasFailure([(@[immediateFail, immediateFail]) asyncRaceOperationsWithWinnerLastingUntil:nil], (@[@"bleh", @"bleh"]));
}
-(void) testAsyncRaceAsynchronousResultUntilCancelledOperationsUntil_Deferred_Win {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCAsyncOperationWithResultLastingUntilCancelled t = ^(TOCCancelToken* until) { return s.future; };
    
    TOCFuture* f = [@[t] asyncRaceOperationsWithWinnerLastingUntil:nil];
    test(f.isIncomplete);
    
    [s trySetResult:@2];
    testFutureHasResult(f, @2);
}
-(void) testAsyncRaceAsynchronousResultUntilCancelledOperationsUntil_Deferred_Fail {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCAsyncOperationWithResultLastingUntilCancelled t = ^(TOCCancelToken* until) { return s.future; };
    
    TOCFuture* f = [@[t] asyncRaceOperationsWithWinnerLastingUntil:nil];
    test(f.isIncomplete);
    
    [s trySetFailure:@3];
    testFutureHasFailure(f, @[@3]);
}
-(void) testAsyncRaceAsynchronousResultUntilCancelledOperationsUntil_Deferred_WinWin {
    TOCFutureSource* s1 = [TOCFutureSource new];
    TOCFutureSource* s2 = [TOCFutureSource new];
    TOCAsyncOperationWithResultLastingUntilCancelled t1 = ^(TOCCancelToken* until) { return s1.future; };
    TOCAsyncOperationWithResultLastingUntilCancelled t2 = ^(TOCCancelToken* until) { return s2.future; };
    
    TOCFuture* f1 = [@[t1, t2] asyncRaceOperationsWithWinnerLastingUntil:nil];
    TOCFuture* f2 = [@[t2, t1] asyncRaceOperationsWithWinnerLastingUntil:nil];
    
    test(f1.isIncomplete);
    test(f2.isIncomplete);
    [s1 forceSetResult:@4];
    
    testFutureHasResult(f1, @4);
    testFutureHasResult(f2, @4);
}
-(void) testAsyncRaceAsynchronousResultUntilCancelledOperationsUntil_Deferred_FailFail {
    TOCFutureSource* s1 = [TOCFutureSource new];
    TOCFutureSource* s2 = [TOCFutureSource new];
    TOCAsyncOperationWithResultLastingUntilCancelled t1 = ^(TOCCancelToken* until) { return s1.future; };
    TOCAsyncOperationWithResultLastingUntilCancelled t2 = ^(TOCCancelToken* until) { return s2.future; };
    
    TOCFuture* f1 = [@[t1, t2] asyncRaceOperationsWithWinnerLastingUntil:nil];
    TOCFuture* f2 = [@[t2, t1] asyncRaceOperationsWithWinnerLastingUntil:nil];
    test(f1.isIncomplete);
    test(f2.isIncomplete);
    
    [s1 forceSetFailure:@5];
    test(f1.isIncomplete);
    test(f2.isIncomplete);
    
    [s2 forceSetFailure:@6];
    testFutureHasFailure(f1, (@[@5, @6]));
    testFutureHasFailure(f2, (@[@6, @5]));
}
-(void) testAsyncRaceAsynchronousResultUntilCancelledOperationsUntil_CancelsLosers {
    TOCFutureSource* s1 = [TOCFutureSource new];
    TOCFutureSource* s2 = [TOCFutureSource new];
    TOCFutureSource* s3 = [TOCFutureSource new];
    TOCAsyncOperationWithResultLastingUntilCancelled t1 = ^(TOCCancelToken* until) { [until whenCancelledTryCancelFutureSource:s1]; return s1.future; };
    TOCAsyncOperationWithResultLastingUntilCancelled t2 = ^(TOCCancelToken* until) { [until whenCancelledTryCancelFutureSource:s2]; return s2.future; };
    TOCAsyncOperationWithResultLastingUntilCancelled t3 = ^(TOCCancelToken* until) { [until whenCancelledTryCancelFutureSource:s3]; return s3.future; };
    
    TOCFuture* f = [@[t1, t2, t3] asyncRaceOperationsWithWinnerLastingUntil:nil];
    test(s1.future.isIncomplete);
    test(s2.future.isIncomplete);
    test(s3.future.isIncomplete);
    test(f.isIncomplete);
    
    [s1 forceSetResult:@7];
    testFutureHasResult(f, @7);
    testFutureHasResult(s1.future, @7);
    test(s2.future.hasFailedWithCancel);
    test(s3.future.hasFailedWithCancel);
}
-(void) testAsyncRaceAsynchronousResultUntilCancelledOperationsUntil_CancelDuring_OperationsFailToCancel {
    TOCFutureSource* s1 = [TOCFutureSource new];
    TOCFutureSource* s2 = [TOCFutureSource new];
    TOCAsyncOperationWithResultLastingUntilCancelled t1 = ^(TOCCancelToken* until) { [until whenCancelledTryCancelFutureSource:s1]; return [TOCFutureSource new].future; };
    TOCAsyncOperationWithResultLastingUntilCancelled t2 = ^(TOCCancelToken* until) { [until whenCancelledTryCancelFutureSource:s2]; return [TOCFutureSource new].future; };
    
    TOCCancelTokenSource* c = [TOCCancelTokenSource new];
    TOCFuture* f = [@[t1, t2] asyncRaceOperationsWithWinnerLastingUntil:c.token];
    test(s1.future.isIncomplete);
    test(s1.future.isIncomplete);
    test(f.isIncomplete);
    
    [c cancel];
    test(f.hasFailedWithCancel);
    test(s1.future.hasFailedWithCancel);
    test(s2.future.hasFailedWithCancel);
}
-(void) testAsyncRaceAsynchronousResultUntilCancelledOperationsUntil_CancelDuringRaceRacersBeingCancelled {
    TOCFutureSource* s1 = [TOCFutureSource new];
    TOCFutureSource* s2 = [TOCFutureSource new];
    TOCAsyncOperationWithResultLastingUntilCancelled t1 = ^(TOCCancelToken* until) { [until whenCancelledTryCancelFutureSource:s1]; return s1.future; };
    TOCAsyncOperationWithResultLastingUntilCancelled t2 = ^(TOCCancelToken* until) { [until whenCancelledTryCancelFutureSource:s2]; return s2.future; };
    
    TOCCancelTokenSource* c = [TOCCancelTokenSource new];
    TOCFuture* f = [@[t1, t2] asyncRaceOperationsWithWinnerLastingUntil:c.token];
    test(s1.future.isIncomplete);
    test(s1.future.isIncomplete);
    test(f.isIncomplete);
    
    [c cancel];
    test(f.hasFailedWithCancel);
    test(s1.future.hasFailedWithCancel);
    test(s2.future.hasFailedWithCancel);
}

@end
