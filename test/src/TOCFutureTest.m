#import <SenTestingKit/SenTestingKit.h>

#import "TOCFuture.h"
#import "TestUtil.h"

@interface TOCFutureTest : SenTestCase

@end

@implementation TOCFutureTest

-(void)testFailedTOCFuture {
    TOCFuture* f = [TOCFuture futureWithFailure:@"X"];

    test(![f isIncomplete]);
    test([f hasFailed]);
    test(![f hasResult]);
    test([[f forceGetFailure] isEqual:@"X"]);
    testThrows([f forceGetResult]);
    test([f description] != nil);
    
    testDoesNotHitTarget([f thenDo:^(id result) { hitTarget; }]);
    testHitsTarget([f catchDo:^(id result) { hitTarget; }]);
    testHitsTarget([f finallyDo:^(id result) { hitTarget; }]);

    testTOCFutureHasFailure([f then:^(id result) { return @2; }], @"X");
    testTOCFutureHasResult([f catch:^(id result) { return @3; }], @3);
    testTOCFutureHasResult([f finally:^(id result) { return @4; }], @4);
}
-(void)testSucceededTOCFuture {
    TOCFuture* f = [TOCFuture futureWithResult:@"X"];
    
    test(![f isIncomplete]);
    test(![f hasFailed]);
    test([f hasResult]);
    test([[f forceGetResult] isEqual:@"X"]);
    testThrows([f forceGetFailure]);
    test([f description] != nil);
    
    testHitsTarget([f thenDo:^(id result) { hitTarget; }]);
    testDoesNotHitTarget([f catchDo:^(id result) { hitTarget; }]);
    testHitsTarget([f finallyDo:^(id result) { hitTarget; }]);
    
    testTOCFutureHasResult([f then:^(id result) { return @2; }], @2);
    testTOCFutureHasResult([f catch:^(id result) { return @3; }], @"X");
    testTOCFutureHasResult([f finally:^(id result) { return @4; }], @4);
}

-(void)testFailedTOCFutureSource {
    TOCFutureSource* f = [TOCFutureSource new];
    test([f trySetFailure:@"X"]);
    
    test(![f isIncomplete]);
    test([f hasFailed]);
    test(![f hasResult]);
    test([[f forceGetFailure] isEqual:@"X"]);
    testThrows([f forceGetResult]);
    test([f description] != nil);
    
    testDoesNotHitTarget([f thenDo:^(id result) { hitTarget; }]);
    testHitsTarget([f catchDo:^(id result) { hitTarget; }]);
    testHitsTarget([f finallyDo:^(id result) { hitTarget; }]);
    
    testTOCFutureHasFailure([f then:^(id result) { return @2; }], @"X");
    testTOCFutureHasResult([f catch:^(id result) { return @3; }], @3);
    testTOCFutureHasResult([f finally:^(id result) { return @4; }], @4);
}
-(void)testSucceededTOCFutureSource {
    TOCFutureSource* f = [TOCFutureSource new];
    test([f trySetResult:@"X"]);
    
    test(![f isIncomplete]);
    test(![f hasFailed]);
    test([f hasResult]);
    test([[f forceGetResult] isEqual:@"X"]);
    testThrows([f forceGetFailure]);
    test([f description] != nil);
    
    testHitsTarget([f thenDo:^(id result) { hitTarget; }]);
    testDoesNotHitTarget([f catchDo:^(id result) { hitTarget; }]);
    testHitsTarget([f finallyDo:^(id result) { hitTarget; }]);
    
    testTOCFutureHasResult([f then:^(id result) { return @2; }], @2);
    testTOCFutureHasResult([f catch:^(id result) { return @3; }], @"X");
    testTOCFutureHasResult([f finally:^(id result) { return @4; }], @4);
}
-(void)testIncompleteTOCFutureSource {
    TOCFutureSource* f = [TOCFutureSource new];
    
    test([f isIncomplete]);
    test(![f hasFailed]);
    test(![f hasResult]);
    testThrows([f forceGetResult]);
    testThrows([f forceGetFailure]);
    test([f description] != nil);
    
    testDoesNotHitTarget([f thenDo:^(id result) { hitTarget; }]);
    testDoesNotHitTarget([f catchDo:^(id result) { hitTarget; }]);
    testDoesNotHitTarget([f finallyDo:^(id result) { hitTarget; }]);
    
    test([[f then:^(id result) { return @2; }] isIncomplete]);
    test([[f catch:^(id result) { return @3; }] isIncomplete]);
    test([[f finally:^(id result) { return @4; }]isIncomplete]);
}

-(void)testCollapsedFailedTOCFutureSource {
    TOCFutureSource* f = [TOCFutureSource new];
    test([f trySetResult:[TOCFuture futureWithFailure:@"X"]]);
    
    test(![f isIncomplete]);
    test([f hasFailed]);
    test(![f hasResult]);
    test([[f forceGetFailure] isEqual:@"X"]);
    testThrows([f forceGetResult]);
    test([f description] != nil);
    
    testDoesNotHitTarget([f thenDo:^(id result) { hitTarget; }]);
    testHitsTarget([f catchDo:^(id result) { hitTarget; }]);
    testHitsTarget([f finallyDo:^(id result) { hitTarget; }]);
    
    testTOCFutureHasFailure([f then:^(id result) { return @2; }], @"X");
    testTOCFutureHasResult([f catch:^(id result) { return @3; }], @3);
    testTOCFutureHasResult([f finally:^(id result) { return @4; }], @4);
}
-(void)testCollapsedSucceededTOCFutureSource {
    TOCFutureSource* f = [TOCFutureSource new];
    test([f trySetResult:[TOCFuture futureWithResult:@"X"]]);
    
    test(![f isIncomplete]);
    test(![f hasFailed]);
    test([f hasResult]);
    test([[f forceGetResult] isEqual:@"X"]);
    testThrows([f forceGetFailure]);
    test([f description] != nil);
    
    testHitsTarget([f thenDo:^(id result) { hitTarget; }]);
    testDoesNotHitTarget([f catchDo:^(id result) { hitTarget; }]);
    testHitsTarget([f finallyDo:^(id result) { hitTarget; }]);
    
    testTOCFutureHasResult([f then:^(id result) { return @2; }], @2);
    testTOCFutureHasResult([f catch:^(id result) { return @3; }], @"X");
    testTOCFutureHasResult([f finally:^(id result) { return @4; }], @4);
}
-(void)testCollapsedIncompleteTOCFutureSource {
    TOCFutureSource* f = [TOCFutureSource new];
    test([f trySetResult:[TOCFutureSource new]]);
    
    test([f isIncomplete]);
    test(![f hasFailed]);
    test(![f hasResult]);
    testThrows([f forceGetResult]);
    testThrows([f forceGetFailure]);
    test([f description] != nil);
    
    testDoesNotHitTarget([f thenDo:^(id result) { hitTarget; }]);
    testDoesNotHitTarget([f catchDo:^(id result) { hitTarget; }]);
    testDoesNotHitTarget([f finallyDo:^(id result) { hitTarget; }]);
    
    test([[f then:^(id result) { return @2; }] isIncomplete]);
    test([[f catch:^(id result) { return @3; }] isIncomplete]);
    test([[f finally:^(id result) { return @4; }]isIncomplete]);
}

-(void)testCyclicCollapsedTOCFutureIsIncomplete {
    TOCFutureSource* f = [TOCFutureSource new];
    test([f trySetResult:f]);
    test([f isIncomplete]);
}

-(void)testDeferredResultThenDo {
    TOCFutureSource* f = [TOCFutureSource new];
    testDoesNotHitTarget([f thenDo:^(id value) { test([value isEqual:@"X"]); hitTarget; }]);
    testHitsTarget([f trySetResult:@"X"]);
}
-(void)testDeferredFailThenDo {
    TOCFutureSource* f = [TOCFutureSource new];
    testDoesNotHitTarget([f thenDo:^(id value) { test(false); hitTarget; }]);
    testDoesNotHitTarget([f trySetFailure:@"X"]);
}
-(void)testDeferredResultCatchDo {
    TOCFutureSource* f = [TOCFutureSource new];
    testDoesNotHitTarget([f catchDo:^(id value) { test(false); hitTarget; }]);
    testDoesNotHitTarget([f trySetResult:@"X"]);
}
-(void)testDeferredFailCatchDo {
    TOCFutureSource* f = [TOCFutureSource new];
    testDoesNotHitTarget([f catchDo:^(id value) { test([value isEqual:@"X"]); hitTarget; }]);
    testHitsTarget([f trySetFailure:@"X"]);
}
-(void)testDeferredResultFinallyDo {
    TOCFutureSource* f = [TOCFutureSource new];
    testDoesNotHitTarget([f finallyDo:^(TOCFuture* value) { test(value == f); hitTarget; }]);
    testHitsTarget([f trySetResult:@"X"]);
}
-(void)testDeferredFailFinallyDo {
    TOCFutureSource* f = [TOCFutureSource new];
    testDoesNotHitTarget([f finallyDo:^(TOCFuture* value) { test(value == f); hitTarget; }]);
    testHitsTarget([f trySetFailure:@"X"]);
}

-(void)testDeferredResultThen {
    TOCFutureSource* f = [TOCFutureSource new];
    TOCFuture* f2 = [f then:^(id value) { test([value isEqual:@"X"]); return @2; }];
    test([f2 isIncomplete]);
    [f trySetResult:@"X"];
    testTOCFutureHasResult(f2, @2);
}
-(void)testDeferredFailThen {
    TOCFutureSource* f = [TOCFutureSource new];
    TOCFuture* f2 = [f then:^(id value) { test(false); return @2; }];
    test([f2 isIncomplete]);
    [f trySetFailure:@"X"];
    testTOCFutureHasFailure(f2, @"X");
}
-(void)testDeferredResultCatch {
    TOCFutureSource* f = [TOCFutureSource new];
    TOCFuture* f2 = [f catch:^(id value) { test(false); return @2; }];
    test([f2 isIncomplete]);
    [f trySetResult:@"X"];
    testTOCFutureHasResult(f2, @"X");
}
-(void)testDeferredFailCatch {
    TOCFutureSource* f = [TOCFutureSource new];
    TOCFuture* f2 = [f catch:^(id value) { test([value isEqual:@"X"]); return @2; }];
    test([f2 isIncomplete]);
    [f trySetFailure:@"X"];
    testTOCFutureHasResult(f2, @2);
}
-(void)testDeferredResultFinally {
    TOCFutureSource* f = [TOCFutureSource new];
    TOCFuture* f2 = [f finally:^(id value) { testTOCFutureHasResult(value, @"X"); return @2; }];
    test([f2 isIncomplete]);
    [f trySetResult:@"X"];
    testTOCFutureHasResult(f2, @2);
}
-(void)testDeferredFailFinally {
    TOCFutureSource* f = [TOCFutureSource new];
    TOCFuture* f2 = [f finally:^(id value) { testTOCFutureHasFailure(value, @"X"); return @2; }];
    test([f2 isIncomplete]);
    [f trySetFailure:@"X"];
    testTOCFutureHasResult(f2, @2);
}
-(void)testTrySetMany1 {
    TOCFutureSource* f = [TOCFutureSource new];
    test([f trySetResult:@1]);
    test(![f trySetResult:@2]);
    test(![f trySetResult:@1]);
    test(![f trySetFailure:@1]);
}
-(void)testTrySetMany2 {
    TOCFutureSource* f = [TOCFutureSource new];
    test([f trySetResult:[TOCFutureSource new]]);
    test(![f trySetResult:@2]);
    test(![f trySetResult:@1]);
    test(![f trySetFailure:@1]);
}
-(void)testTrySetMany3 {
    TOCFutureSource* f = [TOCFutureSource new];
    test([f trySetFailure:@1]);
    test(![f trySetResult:@2]);
    test(![f trySetResult:@1]);
    test(![f trySetFailure:@1]);
}
-(void)testTrySetMany4 {
    TOCFutureSource* f = [TOCFutureSource new];
    test([f trySetFailure:[TOCFutureSource new]]);
    test(![f trySetResult:@2]);
    test(![f trySetResult:@1]);
    test(![f trySetFailure:@1]);
}
-(void)testDeferredResultTrySet {
    TOCFutureSource* f = [TOCFutureSource new];
    TOCFutureSource* g = [TOCFutureSource new];
    [f trySetResult:g];
    test([f isIncomplete]);
    [g trySetResult:@1];
    testTOCFutureHasResult(f, @1);
}
-(void)testDeferredFailTrySet {
    TOCFutureSource* f = [TOCFutureSource new];
    TOCFutureSource* g = [TOCFutureSource new];
    [f trySetResult:g];
    test([f isIncomplete]);
    [g trySetFailure:@1];
    testTOCFutureHasFailure(f, @1);
}

@end
