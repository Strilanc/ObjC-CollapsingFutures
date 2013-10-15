#import <SenTestingKit/SenTestingKit.h>

#import "TocFutureMoreContinuations.h"
#import "TestUtil.h"

@interface TOCFutureMoreContinuationsTest : SenTestCase
@end

@implementation TOCFutureMoreContinuationsTest

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

-(void)testThen_DeferredResult {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCFuture* f = s.future;
    TOCFuture* f2 = [f then:^(id value) { test([value isEqual:@"X"]); return @2; }];
    test([f2 isIncomplete]);
    [s trySetResult:@"X"];
    testFutureHasResult(f2, @2);
}
-(void)testThen_DeferredFail {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCFuture* f = s.future;
    TOCFuture* f2 = [f then:^(id value) { test(false); return @2; }];
    test([f2 isIncomplete]);
    [s trySetFailure:@"X"];
    testFutureHasFailure(f2, @"X");
}

-(void)testCatch_DeferredResult {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCFuture* f = s.future;
    TOCFuture* f2 = [f catch:^(id value) { test(false); return @2; }];
    test([f2 isIncomplete]);
    [s trySetResult:@"X"];
    testFutureHasResult(f2, @"X");
}
-(void)testCatch_DeferredFail {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCFuture* f = s.future;
    TOCFuture* f2 = [f catch:^(id value) { test([value isEqual:@"X"]); return @2; }];
    test([f2 isIncomplete]);
    [s trySetFailure:@"X"];
    testFutureHasResult(f2, @2);
}

-(void)testFinally_DeferredResult {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCFuture* f = s.future;
    TOCFuture* f2 = [f finally:^(id value) { testFutureHasResult(value, @"X"); return @2; }];
    test([f2 isIncomplete]);
    [s trySetResult:@"X"];
    testFutureHasResult(f2, @2);
}
-(void)testFinally_DeferredFail {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCFuture* f = s.future;
    TOCFuture* f2 = [f finally:^(id value) { testFutureHasFailure(value, @"X"); return @2; }];
    test([f2 isIncomplete]);
    [s trySetFailure:@"X"];
    testFutureHasResult(f2, @2);
}

-(void) testUnless_Immediate {
    TOCCancelToken* cc = [TOCCancelToken cancelledToken];
    
    testFutureHasResult([[TOCFuture futureWithResult:@1] unless:nil], @1);
    testFutureHasResult([[TOCFuture futureWithResult:@2] unless:[TOCCancelToken immortalToken]], @2);
    
    testFutureHasFailure([[TOCFuture futureWithFailure:@3] unless:nil], @3);
    testFutureHasFailure([[TOCFuture futureWithFailure:@4] unless:[TOCCancelToken immortalToken]], @4);
    
    testFutureHasFailure([[TOCFuture futureWithResult:@5] unless:cc], cc);
    testFutureHasFailure([[TOCFuture futureWithFailure:@6] unless:cc], cc);
}
-(void) testUnless_DeferredCompletion {
    TOCCancelTokenSource* c = [TOCCancelTokenSource new];
    TOCFutureSource* s = [TOCFutureSource new];
    
    TOCFuture* f = [s.future unless:c.token];
    test([f isIncomplete]);
    [s trySetResult:@1];
    testFutureHasResult(f, @1);
}
-(void) testUnless_DeferredFailure {
    TOCCancelTokenSource* c = [TOCCancelTokenSource new];
    TOCFutureSource* s = [TOCFutureSource new];
    
    TOCFuture* f = [s.future unless:c.token];
    test([f isIncomplete]);
    [s trySetFailure:@2];
    testFutureHasFailure(f, @2);
}
-(void) testUnless_DeferredCancel {
    TOCCancelTokenSource* c = [TOCCancelTokenSource new];
    TOCFutureSource* s = [TOCFutureSource new];
    
    TOCFuture* f = [s.future unless:c.token];
    test([f isIncomplete]);
    [c cancel];
    testFutureHasFailure(f, c.token);
}

@end
