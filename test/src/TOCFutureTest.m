#import <SenTestingKit/SenTestingKit.h>

#import "TwistedOakCollapsingFutures.h"
#import "TestUtil.h"

@interface TOCFutureTest : SenTestCase

@end

@implementation TOCFutureTest

-(void)testFailedFuture {
    TOCFuture* f = [TOCFuture futureWithFailure:@"X"];

    test(![f isIncomplete]);
    test([f hasFailed]);
    test(![f hasResult]);
    test([[f forceGetFailure] isEqual:@"X"]);
    testThrows([f forceGetResult]);
    test([f description] != nil);

    // redundant check of continuations all in one place
    testDoesNotHitTarget([f thenDo:^(id result) { hitTarget; }]);
    testHitsTarget([f catchDo:^(id result) { hitTarget; }]);
    testHitsTarget([f finallyDo:^(id result) { hitTarget; }]);
    testFutureHasFailure([f then:^(id result) { return @2; }], @"X");
    testFutureHasResult([f catch:^(id result) { return @3; }], @3);
    testFutureHasResult([f finally:^(id result) { return @4; }], @4);
}
-(void)testSucceededFuture {
    TOCFuture* f = [TOCFuture futureWithResult:@"X"];
    
    test(![f isIncomplete]);
    test(![f hasFailed]);
    test([f hasResult]);
    test([[f forceGetResult] isEqual:@"X"]);
    testThrows([f forceGetFailure]);
    test([f description] != nil);
    
    // redundant check of continuations all in one place
    testHitsTarget([f thenDo:^(id result) { hitTarget; }]);
    testDoesNotHitTarget([f catchDo:^(id result) { hitTarget; }]);
    testHitsTarget([f finallyDo:^(id result) { hitTarget; }]);
    testFutureHasResult([f then:^(id result) { return @2; }], @2);
    testFutureHasResult([f catch:^(id result) { return @3; }], @"X");
    testFutureHasResult([f finally:^(id result) { return @4; }], @4);
}

-(void)testFinallyDoUnless_Immediate {
    testDoesNotHitTarget([[TOCFutureSource new].future finallyDo:^(TOCFuture* completed) { hitTarget; } unless:nil]);
    testHitsTarget([[TOCFuture futureWithResult:@7] finallyDo:^(TOCFuture* completed) { testFutureHasResult(completed, @7); hitTarget; } unless:nil]);
    testHitsTarget([[TOCFuture futureWithFailure:@8] finallyDo:^(TOCFuture* completed) { testFutureHasFailure(completed, @8); hitTarget; } unless:nil]);

    TOCCancelTokenSource* c = [TOCCancelTokenSource new];
    testDoesNotHitTarget([[TOCFutureSource new].future finallyDo:^(TOCFuture* completed) { hitTarget; } unless:c.token]);
    testHitsTarget([[TOCFuture futureWithResult:@7] finallyDo:^(TOCFuture* completed) { testFutureHasResult(completed, @7); hitTarget; } unless:c.token]);
    testHitsTarget([[TOCFuture futureWithFailure:@8] finallyDo:^(TOCFuture* completed) { testFutureHasFailure(completed, @8); hitTarget; } unless:c.token]);
    
    [c cancel];
    testDoesNotHitTarget([[TOCFutureSource new].future finallyDo:^(TOCFuture* completed) { hitTarget; } unless:c.token]);
    testDoesNotHitTarget([[TOCFuture futureWithResult:@7] finallyDo:^(TOCFuture* completed) { hitTarget; } unless:c.token]);
    testDoesNotHitTarget([[TOCFuture futureWithFailure:@8] finallyDo:^(TOCFuture* completed) { hitTarget; } unless:c.token]);
}
-(void)testFinallyDoUnless_DeferredResult {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCFuture* f = s.future;
    TOCCancelTokenSource* c = [TOCCancelTokenSource new];
    testDoesNotHitTarget([f finallyDo:^(TOCFuture* value) { test(value == f); hitTarget; } unless:[c token]]);
    testHitsTarget([s trySetResult:@"X"]);
}
-(void)testFinallyDoUnless_DeferredFail {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCFuture* f = s.future;
    TOCCancelTokenSource* c = [TOCCancelTokenSource new];
    testDoesNotHitTarget([f finallyDo:^(TOCFuture* value) { test(value == f); hitTarget; } unless:[c token]]);
    testHitsTarget([s trySetFailure:@"X"]);
}
-(void)testFinallyDoUnless_DeferredCancel {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCFuture* f = s.future;
    TOCCancelTokenSource* c = [TOCCancelTokenSource new];
    testDoesNotHitTarget([f finallyDo:^(TOCFuture* value) { test(false); hitTarget; } unless:[c token]]);
    [c cancel];
    testDoesNotHitTarget([s trySetFailure:@"X"]);
}

-(void)testFinallyUnless_Immediate {
    testDoesNotHitTarget([[TOCFutureSource new].future finally:^id(TOCFuture* completed) { hitTarget; return nil; } unless:nil]);
    testHitsTarget([[TOCFuture futureWithResult:@7] finally:^id(TOCFuture* completed) { testFutureHasResult(completed, @7); hitTarget; return nil; } unless:nil]);
    testHitsTarget([[TOCFuture futureWithFailure:@8] finally:^id(TOCFuture* completed) { testFutureHasFailure(completed, @8); hitTarget; return nil; } unless:nil]);
    test([[[TOCFutureSource new].future finally:^id(TOCFuture* completed) { return @1; } unless:nil] isIncomplete]);
    testFutureHasResult([[TOCFuture futureWithResult:@7] finally:^id(TOCFuture* completed) { return @2; } unless:nil], @2);
    testFutureHasResult([[TOCFuture futureWithFailure:@8] finally:^id(TOCFuture* completed) { return @3; } unless:nil], @3);
    
    TOCCancelTokenSource* c = [TOCCancelTokenSource new];
    testDoesNotHitTarget([[TOCFutureSource new].future finally:^id(TOCFuture* completed) { hitTarget; return nil; } unless:c.token]);
    testHitsTarget([[TOCFuture futureWithResult:@7] finally:^id(TOCFuture* completed) { testFutureHasResult(completed, @7); hitTarget; return nil; } unless:c.token]);
    testHitsTarget([[TOCFuture futureWithFailure:@8] finally:^id(TOCFuture* completed) { testFutureHasFailure(completed, @8); hitTarget; return nil; } unless:c.token]);
    test([[[TOCFutureSource new].future finally:^id(TOCFuture* completed) { return @1; } unless:c.token] isIncomplete]);
    testFutureHasResult([[TOCFuture futureWithResult:@7] finally:^id(TOCFuture* completed) { return @2; } unless:c.token], @2);
    testFutureHasResult([[TOCFuture futureWithFailure:@8] finally:^id(TOCFuture* completed) { return @3; } unless:c.token], @3);
    
    [c cancel];
    testDoesNotHitTarget([[TOCFutureSource new].future finally:^id(TOCFuture* completed) { hitTarget; return nil; } unless:c.token]);
    testDoesNotHitTarget([[TOCFuture futureWithResult:@7] finally:^id(TOCFuture* completed) { hitTarget; return nil; } unless:c.token]);
    testDoesNotHitTarget([[TOCFuture futureWithFailure:@8] finally:^id(TOCFuture* completed) { hitTarget; return nil; } unless:c.token]);
    test([[[TOCFutureSource new].future finally:^id(TOCFuture* completed) { return @1; } unless:c.token] hasFailedWithCancel]);
    test([[[TOCFuture futureWithResult:@7] finally:^id(TOCFuture* completed) { return @2; } unless:c.token] hasFailedWithCancel]);
    test([[[TOCFuture futureWithFailure:@8] finally:^id(TOCFuture* completed) { return @3; } unless:c.token] hasFailedWithCancel]);
}

-(void)testThenDoUnless_Immediate {
    testDoesNotHitTarget([[TOCFutureSource new].future thenDo:^(id result) { hitTarget; } unless:nil]);
    testHitsTarget([[TOCFuture futureWithResult:@7] thenDo:^(id result) { test([result isEqual:@7]); hitTarget; } unless:nil]);
    testDoesNotHitTarget([[TOCFuture futureWithFailure:@8] thenDo:^(id result) { hitTarget; } unless:nil]);
    
    TOCCancelTokenSource* c = [TOCCancelTokenSource new];
    testDoesNotHitTarget([[TOCFutureSource new].future thenDo:^(id result) { hitTarget; } unless:c.token]);
    testHitsTarget([[TOCFuture futureWithResult:@7] thenDo:^(id result) { test([result isEqual:@7]); hitTarget; } unless:c.token]);
    testDoesNotHitTarget([[TOCFuture futureWithFailure:@8] thenDo:^(id result) { hitTarget; } unless:c.token]);
    
    [c cancel];
    testDoesNotHitTarget([[TOCFutureSource new].future thenDo:^(id result) { hitTarget; } unless:c.token]);
    testDoesNotHitTarget([[TOCFuture futureWithResult:@7] thenDo:^(id result) { hitTarget; } unless:c.token]);
    testDoesNotHitTarget([[TOCFuture futureWithFailure:@8] thenDo:^(id result) { hitTarget; } unless:c.token]);
}

-(void)testThenUnless_Immediate {
    testDoesNotHitTarget([[TOCFutureSource new].future then:^id(id result) { hitTarget; return nil; } unless:nil]);
    testHitsTarget([[TOCFuture futureWithResult:@7] then:^id(id result) { test([result isEqual:@7]); hitTarget; return nil; } unless:nil]);
    testDoesNotHitTarget([[TOCFuture futureWithFailure:@8] then:^id(id result) { hitTarget; return nil; } unless:nil]);
    test([[[TOCFutureSource new].future then:^id(id result) { return @1; } unless:nil] isIncomplete]);
    testFutureHasResult([[TOCFuture futureWithResult:@7] then:^id(id result) { return @2; } unless:nil], @2);
    testFutureHasFailure([[TOCFuture futureWithFailure:@8] then:^id(id result) { return @3; } unless:nil], @8);
    
    TOCCancelTokenSource* c = [TOCCancelTokenSource new];
    testDoesNotHitTarget([[TOCFutureSource new].future then:^id(id result) { hitTarget; return nil; } unless:c.token]);
    testHitsTarget([[TOCFuture futureWithResult:@7] then:^id(id result) { test([result isEqual:@7]); hitTarget; return nil; } unless:c.token]);
    testDoesNotHitTarget([[TOCFuture futureWithFailure:@8] then:^id(id result) { hitTarget; return nil; } unless:c.token]);
    test([[[TOCFutureSource new].future then:^id(id result) { return @1; } unless:c.token] isIncomplete]);
    testFutureHasResult([[TOCFuture futureWithResult:@7] then:^id(id result) { return @2; } unless:c.token], @2);
    testFutureHasFailure([[TOCFuture futureWithFailure:@8] then:^id(id result) { return @3; } unless:c.token], @8);
    
    [c cancel];
    testDoesNotHitTarget([[TOCFutureSource new].future then:^id(id result) { hitTarget; return nil; } unless:c.token]);
    testDoesNotHitTarget([[TOCFuture futureWithResult:@7] then:^id(id result) { hitTarget; return nil; } unless:c.token]);
    testDoesNotHitTarget([[TOCFuture futureWithFailure:@8] then:^id(id result) { hitTarget; return nil; } unless:c.token]);
    test([[[TOCFutureSource new].future then:^id(id result) { return @1; } unless:c.token] hasFailedWithCancel]);
    test([[[TOCFuture futureWithResult:@7] then:^id(id result) { return @2; } unless:c.token] hasFailedWithCancel]);
    test([[[TOCFuture futureWithFailure:@8] then:^id(id result) { return @3; } unless:c.token] hasFailedWithCancel]);
}

-(void)testCatchDoUnless_Immediate {
    testDoesNotHitTarget([[TOCFutureSource new].future catchDo:^(id result) { hitTarget; } unless:nil]);
    testDoesNotHitTarget([[TOCFuture futureWithResult:@7] catchDo:^(id result) { hitTarget; } unless:nil]);
    testHitsTarget([[TOCFuture futureWithFailure:@8] catchDo:^(id result) { test([result isEqual:@8]); hitTarget; } unless:nil]);
    
    TOCCancelTokenSource* c = [TOCCancelTokenSource new];
    testDoesNotHitTarget([[TOCFutureSource new].future catchDo:^(id result) { hitTarget; } unless:c.token]);
    testDoesNotHitTarget([[TOCFuture futureWithResult:@7] catchDo:^(id result) { hitTarget; } unless:c.token]);
    testHitsTarget([[TOCFuture futureWithFailure:@8] catchDo:^(id result) { test([result isEqual:@8]); hitTarget; } unless:c.token]);
    
    [c cancel];
    testDoesNotHitTarget([[TOCFutureSource new].future catchDo:^(id result) { hitTarget; } unless:c.token]);
    testDoesNotHitTarget([[TOCFuture futureWithResult:@7] catchDo:^(id result) { hitTarget; } unless:c.token]);
    testDoesNotHitTarget([[TOCFuture futureWithFailure:@8] catchDo:^(id result) { hitTarget; } unless:c.token]);
}

-(void)testCatchUnless_Immediate {
    testDoesNotHitTarget([[TOCFutureSource new].future catch:^id(id failure) { hitTarget; return nil; } unless:nil]);
    testDoesNotHitTarget([[TOCFuture futureWithResult:@7] catch:^id(id failure) { hitTarget; return nil; } unless:nil]);
    testHitsTarget([[TOCFuture futureWithFailure:@8] catch:^id(id failure) { test([failure isEqual:@8]); hitTarget; return nil; } unless:nil]);
    test([[[TOCFutureSource new].future catch:^id(id failure) { return @1; } unless:nil] isIncomplete]);
    testFutureHasResult([[TOCFuture futureWithResult:@7] catch:^id(id failure) { return @2; } unless:nil], @7);
    testFutureHasResult([[TOCFuture futureWithFailure:@8] catch:^id(id failure) { return @3; } unless:nil], @3);
    
    TOCCancelTokenSource* c = [TOCCancelTokenSource new];
    testDoesNotHitTarget([[TOCFutureSource new].future catch:^id(id failure) { hitTarget; return nil; } unless:c.token]);
    testDoesNotHitTarget([[TOCFuture futureWithResult:@7] catch:^id(id failure) { hitTarget; return nil; } unless:c.token]);
    testHitsTarget([[TOCFuture futureWithFailure:@8] catch:^id(id failure) { test([failure isEqual:@8]); hitTarget; return nil; } unless:c.token]);
    test([[[TOCFutureSource new].future catch:^id(id failure) { return @1; } unless:c.token] isIncomplete]);
    testFutureHasResult([[TOCFuture futureWithResult:@7] catch:^id(id failure) { return @2; } unless:c.token], @7);
    testFutureHasResult([[TOCFuture futureWithFailure:@8] catch:^id(id failure) { return @3; } unless:c.token], @3);
    
    [c cancel];
    testDoesNotHitTarget([[TOCFutureSource new].future catch:^id(id failure) { hitTarget; return nil; } unless:c.token]);
    testDoesNotHitTarget([[TOCFuture futureWithResult:@7] catch:^id(id failure) { hitTarget; return nil; } unless:c.token]);
    testDoesNotHitTarget([[TOCFuture futureWithFailure:@8] catch:^id(id failure) { hitTarget; return nil; } unless:c.token]);
    test([[[TOCFutureSource new].future catch:^id(id failure) { return @1; } unless:c.token] hasFailedWithCancel]);
    test([[[TOCFuture futureWithResult:@7] catch:^id(id failure) { return @2; } unless:c.token] hasFailedWithCancel]);
    test([[[TOCFuture futureWithFailure:@8] catch:^id(id failure) { return @3; } unless:c.token] hasFailedWithCancel]);
}

@end
