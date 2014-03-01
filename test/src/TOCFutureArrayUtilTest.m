#import "Testing.h"
#import "NSArray+TOCFuture.h"

#define fut(X) [TOCFuture futureWithResult:X]
#define futfail(X) [TOCFuture futureWithFailure:X]

@interface TOCFutureArrayUtilTest : SenTestCase
@end

@implementation TOCFutureArrayUtilTest

-(void)testOrderedByCompletion {
    testEq(@[].toc_orderedByCompletion, @[]);
    testThrows([(@[@1]) toc_orderedByCompletion]);
    
    NSArray* s = (@[[TOCFutureSource new], [TOCFutureSource new], [TOCFutureSource new]]);
    NSArray* f = (@[[s[0] future], [s[1] future], [s[2] future]]);
    NSArray* g = [f toc_orderedByCompletion];
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
    NSArray* g2 = [f toc_orderedByCompletion];
    testFutureHasResult(g2[0], @"C");
    testFutureHasResult(g2[1], @"A");
    testFutureHasFailure(g2[2], @"B");
}
-(void) testFinallyAll {
    testThrows(@[@1].toc_finallyAll);
    testFutureHasResult(@[].toc_finallyAll, @[]);
    
    TOCFuture* f = (@[fut(@1), futfail(@2)]).toc_finallyAll;
    test(f.hasResult);
    NSArray* x = f.forceGetResult;
    test(x.count == 2);
    testFutureHasResult(x[0], @1);
    testFutureHasFailure(x[1], @2);
}
-(void) testFinallyAll_Incomplete {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCFuture* f = (@[fut(@1), s.future, fut(@3)]).toc_finallyAll;
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
    testThrows(@[@1].toc_thenAll);
    testFutureHasResult(@[].toc_thenAll, @[]);
    testFutureHasResult((@[fut(@3)]).toc_thenAll, (@[@3]));
    testFutureHasResult((@[fut(@1), fut(@2)]).toc_thenAll, (@[@1, @2]));
    
    TOCFuture* f = @[fut(@1), futfail(@2)].toc_thenAll;
    test(f.hasFailed);
    NSArray* x = f.forceGetFailure;
    test(x.count == 2);
    testFutureHasResult(x[0], @1);
    testFutureHasFailure(x[1], @2);
}
-(void) testThenAll_Incomplete {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCFuture* f = @[fut(@1), s.future, fut(@3)].toc_thenAll;
    test(f.isIncomplete);
    [s trySetResult:@""];
    testFutureHasResult(f, (@[@1, @"", @3]));
}
-(void) testAsyncRaceAsynchronousResultUntilCancelledOperationsUntil_Failures {
    testThrows([@[] toc_raceForWinnerLastingUntil:nil]);
    testThrows([@[@1] toc_raceForWinnerLastingUntil:nil]);
    testThrows([(@[[TOCFuture futureWithResult:@1]]) toc_raceForWinnerLastingUntil:nil]);
}
-(void) testAsyncRaceAsynchronousResultUntilCancelledOperationsUntil_Immediate {
    TOCUntilOperation immediate1 = ^(TOCCancelToken* until) {
        hitTarget;
        test(until != nil);
        return [TOCFuture futureWithResult:@1];
    };
    TOCUntilOperation immediateFail = ^(TOCCancelToken* until) {
        test(until != nil);
        return [TOCFuture futureWithFailure:@"bleh"];
    };
    
    testHitsTarget([@[immediate1] toc_raceForWinnerLastingUntil:nil]);
    testFutureHasResult([@[immediate1] toc_raceForWinnerLastingUntil:nil], @1);
    testFutureHasResult([(@[immediate1, immediateFail]) toc_raceForWinnerLastingUntil:nil], @1);
    testFutureHasResult([(@[immediateFail, immediate1]) toc_raceForWinnerLastingUntil:nil], @1);
    testFutureHasFailure([(@[immediateFail, immediateFail]) toc_raceForWinnerLastingUntil:nil], (@[@"bleh", @"bleh"]));
}
-(void) testAsyncRaceAsynchronousResultUntilCancelledOperationsUntil_Deferred_Win {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCUntilOperation t = ^(TOCCancelToken* until) { return s.future; };
    
    TOCFuture* f = [@[t] toc_raceForWinnerLastingUntil:nil];
    test(f.isIncomplete);
    
    [s trySetResult:@2];
    testFutureHasResult(f, @2);
}
-(void) testAsyncRaceAsynchronousResultUntilCancelledOperationsUntil_Deferred_Fail {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCUntilOperation t = ^(TOCCancelToken* until) { return s.future; };
    
    TOCFuture* f = [@[t] toc_raceForWinnerLastingUntil:nil];
    test(f.isIncomplete);
    
    [s trySetFailure:@3];
    testFutureHasFailure(f, @[@3]);
}
-(void) testAsyncRaceAsynchronousResultUntilCancelledOperationsUntil_Deferred_WinWin {
    TOCFutureSource* s1 = [TOCFutureSource new];
    TOCFutureSource* s2 = [TOCFutureSource new];
    TOCUntilOperation t1 = ^(TOCCancelToken* until) { return s1.future; };
    TOCUntilOperation t2 = ^(TOCCancelToken* until) { return s2.future; };
    
    TOCFuture* f1 = [@[t1, t2] toc_raceForWinnerLastingUntil:nil];
    TOCFuture* f2 = [@[t2, t1] toc_raceForWinnerLastingUntil:nil];
    
    test(f1.isIncomplete);
    test(f2.isIncomplete);
    [s1 forceSetResult:@4];
    
    testFutureHasResult(f1, @4);
    testFutureHasResult(f2, @4);
}
-(void) testAsyncRaceAsynchronousResultUntilCancelledOperationsUntil_Deferred_FailFail {
    TOCFutureSource* s1 = [TOCFutureSource new];
    TOCFutureSource* s2 = [TOCFutureSource new];
    TOCUntilOperation t1 = ^(TOCCancelToken* until) { return s1.future; };
    TOCUntilOperation t2 = ^(TOCCancelToken* until) { return s2.future; };
    
    TOCFuture* f1 = [@[t1, t2] toc_raceForWinnerLastingUntil:nil];
    TOCFuture* f2 = [@[t2, t1] toc_raceForWinnerLastingUntil:nil];
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
    TOCUntilOperation t1 = ^(TOCCancelToken* until) { [until whenCancelledDo:^{ [s1 trySetFailedWithCancel]; }]; return s1.future; };
    TOCUntilOperation t2 = ^(TOCCancelToken* until) { [until whenCancelledDo:^{ [s2 trySetFailedWithCancel]; }]; return s2.future; };
    TOCUntilOperation t3 = ^(TOCCancelToken* until) { [until whenCancelledDo:^{ [s3 trySetFailedWithCancel]; }]; return s3.future; };
    
    TOCFuture* f = [@[t1, t2, t3] toc_raceForWinnerLastingUntil:nil];
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
    TOCUntilOperation t1 = ^(TOCCancelToken* until) { [until whenCancelledDo:^{ [s1 trySetFailedWithCancel]; }]; return [TOCFutureSource new].future; };
    TOCUntilOperation t2 = ^(TOCCancelToken* until) { [until whenCancelledDo:^{ [s2 trySetFailedWithCancel]; }]; return [TOCFutureSource new].future; };
    
    TOCCancelTokenSource* c = [TOCCancelTokenSource new];
    TOCFuture* f = [@[t1, t2] toc_raceForWinnerLastingUntil:c.token];
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
    TOCUntilOperation t1 = ^(TOCCancelToken* until) { [until whenCancelledDo:^{ [s1 trySetFailedWithCancel]; }]; return s1.future; };
    TOCUntilOperation t2 = ^(TOCCancelToken* until) { [until whenCancelledDo:^{ [s2 trySetFailedWithCancel]; }]; return s2.future; };
    
    TOCCancelTokenSource* c = [TOCCancelTokenSource new];
    TOCFuture* f = [@[t1, t2] toc_raceForWinnerLastingUntil:c.token];
    test(s1.future.isIncomplete);
    test(s1.future.isIncomplete);
    test(f.isIncomplete);
    
    [c cancel];
    test(f.hasFailedWithCancel);
    test(s1.future.hasFailedWithCancel);
    test(s2.future.hasFailedWithCancel);
}

@end
