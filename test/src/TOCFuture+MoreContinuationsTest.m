#import <SenTestingKit/SenTestingKit.h>

#import "TOCFuture+MoreContinuations.h"
#import "TestUtil.h"

@interface TOCFutureMoreContinuationsTest : SenTestCase
@end

@implementation TOCFutureMoreContinuationsTest

-(void)testFinallyDo_Immediate {
    testDoesNotHitTarget([[TOCFutureSource new].future finallyDo:^(TOCFuture* completed) { hitTarget; }]);
    testHitsTarget([[TOCFuture futureWithResult:@7] finallyDo:^(TOCFuture* completed) { testFutureHasResult(completed, @7); hitTarget; }]);
    testHitsTarget([[TOCFuture futureWithFailure:@8] finallyDo:^(TOCFuture* completed) { testFutureHasFailure(completed, @8); hitTarget; }]);
}
-(void)testFinallyDo_DeferredResult {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCFuture* f = s.future;
    testDoesNotHitTarget([f finallyDo:^(TOCFuture* value) { test(value == f); hitTarget; }]);
    testHitsTarget([s trySetResult:@"X"]);
}
-(void)testFinallyDo_DeferredFail {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCFuture* f = s.future;
    testDoesNotHitTarget([f finallyDo:^(TOCFuture* value) { test(value == f); hitTarget; }]);
    testHitsTarget([s trySetFailure:@"X"]);
}

-(void)testThenDo_Immediate {
    testDoesNotHitTarget([[TOCFutureSource new].future thenDo:^(id result) { hitTarget; }]);
    testHitsTarget([[TOCFuture futureWithResult:@7] thenDo:^(id result) { test([result isEqual:@7]); hitTarget; }]);
    testDoesNotHitTarget([[TOCFuture futureWithFailure:@8] thenDo:^(id result) { hitTarget; }]);
}
-(void)testThenDo_DeferredResult {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCFuture* f = s.future;
    testDoesNotHitTarget([f thenDo:^(id value) { test([value isEqual:@"X"]); hitTarget; }]);
    testHitsTarget([s trySetResult:@"X"]);
}
-(void)testThenDo_DeferredFail {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCFuture* f = s.future;
    testDoesNotHitTarget([f thenDo:^(id value) { test(false); hitTarget; }]);
    testDoesNotHitTarget([s trySetFailure:@"X"]);
}

-(void)testCatchDo_Immediate {
    testDoesNotHitTarget([[TOCFutureSource new].future catchDo:^(id failure) { hitTarget; }]);
    testDoesNotHitTarget([[TOCFuture futureWithResult:@7] catchDo:^(id failure) { hitTarget; }]);
    testHitsTarget([[TOCFuture futureWithFailure:@8] catchDo:^(id failure) { test([failure isEqual:@8]); hitTarget; }]);
}
-(void)testCatchDo_DeferredResult {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCFuture* f = s.future;
    testDoesNotHitTarget([f catchDo:^(id value) { test(false); hitTarget; }]);
    testDoesNotHitTarget([s trySetResult:@"X"]);
}
-(void)testCatchDo_DeferredFail {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCFuture* f = s.future;
    testDoesNotHitTarget([f catchDo:^(id value) { test([value isEqual:@"X"]); hitTarget; }]);
    testHitsTarget([s trySetFailure:@"X"]);
}

-(void)testThen_Immediate {
    testFutureHasResult([[TOCFuture futureWithResult:@1] then:^(id result) { return @2; }], @2);
    testFutureHasFailure([[TOCFuture futureWithFailure:@3] then:^(id result) { return @4; }], @3);
    testFutureHasFailure([[TOCFuture futureWithResult:@5] then:^(id result) { return [TOCFuture futureWithFailure:@6]; }], @6);

    testDoesNotHitTarget([[TOCFutureSource new].future then:^id(id result) { hitTarget; return nil; }]);
    testHitsTarget([[TOCFuture futureWithResult:@7] then:^id(id result) { test([result isEqual:@7]); hitTarget; return nil; }]);
    testDoesNotHitTarget([[TOCFuture futureWithFailure:@8] then:^id(id result) { hitTarget; return nil; }]);
}
-(void)testThen_DeferredResult {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCFuture* f = s.future;
    TOCFuture* f2 = [f then:^(id value) { test([value isEqual:@"X"]); return @2; }];
    test(f2.isIncomplete);
    [s trySetResult:@"X"];
    testFutureHasResult(f2, @2);
}
-(void)testThen_DeferredFail {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCFuture* f = s.future;
    TOCFuture* f2 = [f then:^(id value) { test(false); return @2; }];
    test(f2.isIncomplete);
    [s trySetFailure:@"X"];
    testFutureHasFailure(f2, @"X");
}

-(void)testCatch_Immediate {
    testFutureHasResult([[TOCFuture futureWithResult:@1] catch:^(id failure) { return @2; }], @1);
    testFutureHasResult([[TOCFuture futureWithFailure:@3] catch:^(id failure) { return @4; }], @4);
    testFutureHasFailure([[TOCFuture futureWithFailure:@5] catch:^(id failure) { return [TOCFuture futureWithFailure:@6]; }], @6);

    testDoesNotHitTarget([[TOCFutureSource new].future catch:^id(id failure) { hitTarget; return nil; }]);
    testDoesNotHitTarget([[TOCFuture futureWithResult:@1] catch:^id(id failure) { hitTarget; return nil; }]);
    testHitsTarget([[TOCFuture futureWithFailure:@8] catch:^id(id failure) { test([failure isEqual:@8]); hitTarget; return nil; }]);
}
-(void)testCatch_DeferredResult {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCFuture* f = s.future;
    TOCFuture* f2 = [f catch:^(id value) { test(false); return @2; }];
    test(f2.isIncomplete);
    [s trySetResult:@"X"];
    testFutureHasResult(f2, @"X");
}
-(void)testCatch_DeferredFail {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCFuture* f = s.future;
    TOCFuture* f2 = [f catch:^(id value) { test([value isEqual:@"X"]); return @2; }];
    test(f2.isIncomplete);
    [s trySetFailure:@"X"];
    testFutureHasResult(f2, @2);
}

-(void)testFinally_Immediate {
    testFutureHasResult([[TOCFuture futureWithResult:@1] finally:^(TOCFuture *completed) { return @2; }], @2);
    testFutureHasResult([[TOCFuture futureWithFailure:@3] finally:^(TOCFuture *completed) { return @4; }], @4);
    testFutureHasFailure([[TOCFuture futureWithFailure:@5] finally:^(TOCFuture *completed) { return [TOCFuture futureWithFailure:@6]; }], @6);

    testDoesNotHitTarget([[TOCFutureSource new].future finally:^id(TOCFuture *completed) { hitTarget; return nil; }]);
    testHitsTarget([[TOCFuture futureWithResult:@7] finally:^id(TOCFuture *completed) { testFutureHasResult(completed, @7); hitTarget; return nil; }]);
    testHitsTarget([[TOCFuture futureWithFailure:@8] finally:^id(TOCFuture *completed) { testFutureHasFailure(completed, @8); hitTarget; return nil; }]);
}
-(void)testFinally_DeferredResult {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCFuture* f = s.future;
    TOCFuture* f2 = [f finally:^(id value) { testFutureHasResult(value, @"X"); return @2; }];
    test(f2.isIncomplete);
    [s trySetResult:@"X"];
    testFutureHasResult(f2, @2);
}
-(void)testFinally_DeferredFail {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCFuture* f = s.future;
    TOCFuture* f2 = [f finally:^(id value) { testFutureHasFailure(value, @"X"); return @2; }];
    test(f2.isIncomplete);
    [s trySetFailure:@"X"];
    testFutureHasResult(f2, @2);
}

-(void) testUnless_Immediate {
    TOCCancelToken* cc = TOCCancelToken.cancelledToken;
    
    testFutureHasResult([[TOCFuture futureWithResult:@1] unless:nil], @1);
    testFutureHasResult([[TOCFuture futureWithResult:@2] unless:TOCCancelToken.immortalToken], @2);
    
    testFutureHasFailure([[TOCFuture futureWithFailure:@3] unless:nil], @3);
    testFutureHasFailure([[TOCFuture futureWithFailure:@4] unless:TOCCancelToken.immortalToken], @4);
    
    testFutureHasFailure([[TOCFuture futureWithResult:@5] unless:cc], cc);
    testFutureHasFailure([[TOCFuture futureWithFailure:@6] unless:cc], cc);
}
-(void) testUnless_DeferredCompletion {
    TOCCancelTokenSource* c = [TOCCancelTokenSource new];
    TOCFutureSource* s = [TOCFutureSource new];
    
    TOCFuture* f = [s.future unless:c.token];
    test(f.isIncomplete);
    [s trySetResult:@1];
    testFutureHasResult(f, @1);
}
-(void) testUnless_DeferredFailure {
    TOCCancelTokenSource* c = [TOCCancelTokenSource new];
    TOCFutureSource* s = [TOCFutureSource new];
    
    TOCFuture* f = [s.future unless:c.token];
    test(f.isIncomplete);
    [s trySetFailure:@2];
    testFutureHasFailure(f, @2);
}
-(void) testUnless_DeferredCancel {
    TOCCancelTokenSource* c = [TOCCancelTokenSource new];
    TOCFutureSource* s = [TOCFutureSource new];
    
    TOCFuture* f = [s.future unless:c.token];
    test(f.isIncomplete);
    [c cancel];
    test(f.hasFailedWithCancel);
}

@end
