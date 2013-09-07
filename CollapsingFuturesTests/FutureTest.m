#import "FutureTest.h"
#import "Future.h"
#import "TestUtil.h"

@implementation FutureTest

-(void)testFailedFuture {
    Future* f = [Future futureWithFailure:@"X"];

    test(![f isIncomplete]);
    test([f hasFailed]);
    test(![f hasResult]);
    test([[f forceGetFailure] isEqual:@"X"]);
    testThrows([f forceGetResult]);
    test([f description] != nil);
    
    testDoesNotHitTarget([f thenDo:^(id result) { hitTarget; }]);
    testHitsTarget([f catchDo:^(id result) { hitTarget; }]);
    testHitsTarget([f finallyDo:^(id result) { hitTarget; }]);

    testFutureHasFailure([f then:^(id result) { return @2; }], @"X");
    testFutureHasResult([f catch:^(id result) { return @3; }], @3);
    testFutureHasResult([f finally:^(id result) { return @4; }], @4);
}
-(void)testSucceededFuture {
    Future* f = [Future futureWithResult:@"X"];
    
    test(![f isIncomplete]);
    test(![f hasFailed]);
    test([f hasResult]);
    test([[f forceGetResult] isEqual:@"X"]);
    testThrows([f forceGetFailure]);
    test([f description] != nil);
    
    testHitsTarget([f thenDo:^(id result) { hitTarget; }]);
    testDoesNotHitTarget([f catchDo:^(id result) { hitTarget; }]);
    testHitsTarget([f finallyDo:^(id result) { hitTarget; }]);
    
    testFutureHasResult([f then:^(id result) { return @2; }], @2);
    testFutureHasResult([f catch:^(id result) { return @3; }], @"X");
    testFutureHasResult([f finally:^(id result) { return @4; }], @4);
}

-(void)testFailedFutureSource {
    FutureSource* f = [FutureSource new];
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
    
    testFutureHasFailure([f then:^(id result) { return @2; }], @"X");
    testFutureHasResult([f catch:^(id result) { return @3; }], @3);
    testFutureHasResult([f finally:^(id result) { return @4; }], @4);
}
-(void)testSucceededFutureSource {
    FutureSource* f = [FutureSource new];
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
    
    testFutureHasResult([f then:^(id result) { return @2; }], @2);
    testFutureHasResult([f catch:^(id result) { return @3; }], @"X");
    testFutureHasResult([f finally:^(id result) { return @4; }], @4);
}
-(void)testIncompleteFutureSource {
    FutureSource* f = [FutureSource new];
    
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

-(void)testCollapsedFailedFutureSource {
    FutureSource* f = [FutureSource new];
    test([f trySetResult:[Future futureWithFailure:@"X"]]);
    
    test(![f isIncomplete]);
    test([f hasFailed]);
    test(![f hasResult]);
    test([[f forceGetFailure] isEqual:@"X"]);
    testThrows([f forceGetResult]);
    test([f description] != nil);
    
    testDoesNotHitTarget([f thenDo:^(id result) { hitTarget; }]);
    testHitsTarget([f catchDo:^(id result) { hitTarget; }]);
    testHitsTarget([f finallyDo:^(id result) { hitTarget; }]);
    
    testFutureHasFailure([f then:^(id result) { return @2; }], @"X");
    testFutureHasResult([f catch:^(id result) { return @3; }], @3);
    testFutureHasResult([f finally:^(id result) { return @4; }], @4);
}
-(void)testCollapsedSucceededFutureSource {
    FutureSource* f = [FutureSource new];
    test([f trySetResult:[Future futureWithResult:@"X"]]);
    
    test(![f isIncomplete]);
    test(![f hasFailed]);
    test([f hasResult]);
    test([[f forceGetResult] isEqual:@"X"]);
    testThrows([f forceGetFailure]);
    test([f description] != nil);
    
    testHitsTarget([f thenDo:^(id result) { hitTarget; }]);
    testDoesNotHitTarget([f catchDo:^(id result) { hitTarget; }]);
    testHitsTarget([f finallyDo:^(id result) { hitTarget; }]);
    
    testFutureHasResult([f then:^(id result) { return @2; }], @2);
    testFutureHasResult([f catch:^(id result) { return @3; }], @"X");
    testFutureHasResult([f finally:^(id result) { return @4; }], @4);
}
-(void)testCollapsedIncompleteFutureSource {
    FutureSource* f = [FutureSource new];
    test([f trySetResult:[FutureSource new]]);
    
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

-(void)testCyclicCollapsedFutureIsIncomplete {
    FutureSource* f = [FutureSource new];
    test([f trySetResult:f]);
    test([f isIncomplete]);
}

-(void)testDeferredResultThenDo {
    FutureSource* f = [FutureSource new];
    testDoesNotHitTarget([f thenDo:^(id value) { test([value isEqual:@"X"]); hitTarget; }]);
    testHitsTarget([f trySetResult:@"X"]);
}
-(void)testDeferredFailThenDo {
    FutureSource* f = [FutureSource new];
    testDoesNotHitTarget([f thenDo:^(id value) { test(false); hitTarget; }]);
    testDoesNotHitTarget([f trySetFailure:@"X"]);
}
-(void)testDeferredResultCatchDo {
    FutureSource* f = [FutureSource new];
    testDoesNotHitTarget([f catchDo:^(id value) { test(false); hitTarget; }]);
    testDoesNotHitTarget([f trySetResult:@"X"]);
}
-(void)testDeferredFailCatchDo {
    FutureSource* f = [FutureSource new];
    testDoesNotHitTarget([f catchDo:^(id value) { test([value isEqual:@"X"]); hitTarget; }]);
    testHitsTarget([f trySetFailure:@"X"]);
}
-(void)testDeferredResultFinallyDo {
    FutureSource* f = [FutureSource new];
    testDoesNotHitTarget([f finallyDo:^(Future* value) { test(value == f); hitTarget; }]);
    testHitsTarget([f trySetResult:@"X"]);
}
-(void)testDeferredFailFinallyDo {
    FutureSource* f = [FutureSource new];
    testDoesNotHitTarget([f finallyDo:^(Future* value) { test(value == f); hitTarget; }]);
    testHitsTarget([f trySetFailure:@"X"]);
}

-(void)testDeferredResultThen {
    FutureSource* f = [FutureSource new];
    Future* f2 = [f then:^(id value) { test([value isEqual:@"X"]); return @2; }];
    test([f2 isIncomplete]);
    [f trySetResult:@"X"];
    testFutureHasResult(f2, @2);
}
-(void)testDeferredFailThen {
    FutureSource* f = [FutureSource new];
    Future* f2 = [f then:^(id value) { test(false); return @2; }];
    test([f2 isIncomplete]);
    [f trySetFailure:@"X"];
    testFutureHasFailure(f2, @"X");
}
-(void)testDeferredResultCatch {
    FutureSource* f = [FutureSource new];
    Future* f2 = [f catch:^(id value) { test(false); return @2; }];
    test([f2 isIncomplete]);
    [f trySetResult:@"X"];
    testFutureHasResult(f2, @"X");
}
-(void)testDeferredFailCatch {
    FutureSource* f = [FutureSource new];
    Future* f2 = [f catch:^(id value) { test([value isEqual:@"X"]); return @2; }];
    test([f2 isIncomplete]);
    [f trySetFailure:@"X"];
    testFutureHasResult(f2, @2);
}
-(void)testDeferredResultFinally {
    FutureSource* f = [FutureSource new];
    Future* f2 = [f finally:^(id value) { testFutureHasResult(value, @"X"); return @2; }];
    test([f2 isIncomplete]);
    [f trySetResult:@"X"];
    testFutureHasResult(f2, @2);
}
-(void)testDeferredFailFinally {
    FutureSource* f = [FutureSource new];
    Future* f2 = [f finally:^(id value) { testFutureHasFailure(value, @"X"); return @2; }];
    test([f2 isIncomplete]);
    [f trySetFailure:@"X"];
    testFutureHasResult(f2, @2);
}
-(void)testTrySetMany1 {
    FutureSource* f = [FutureSource new];
    test([f trySetResult:@1]);
    test(![f trySetResult:@2]);
    test(![f trySetResult:@1]);
    test(![f trySetFailure:@1]);
}
-(void)testTrySetMany2 {
    FutureSource* f = [FutureSource new];
    test([f trySetResult:[FutureSource new]]);
    test(![f trySetResult:@2]);
    test(![f trySetResult:@1]);
    test(![f trySetFailure:@1]);
}
-(void)testTrySetMany3 {
    FutureSource* f = [FutureSource new];
    test([f trySetFailure:@1]);
    test(![f trySetResult:@2]);
    test(![f trySetResult:@1]);
    test(![f trySetFailure:@1]);
}
-(void)testTrySetMany4 {
    FutureSource* f = [FutureSource new];
    test([f trySetFailure:[FutureSource new]]);
    test(![f trySetResult:@2]);
    test(![f trySetResult:@1]);
    test(![f trySetFailure:@1]);
}
-(void)testDeferredResultTrySet {
    FutureSource* f = [FutureSource new];
    FutureSource* g = [FutureSource new];
    [f trySetResult:g];
    test([f isIncomplete]);
    [g trySetResult:@1];
    testFutureHasResult(f, @1);
}
-(void)testDeferredFailTrySet {
    FutureSource* f = [FutureSource new];
    FutureSource* g = [FutureSource new];
    [f trySetResult:g];
    test([f isIncomplete]);
    [g trySetFailure:@1];
    testFutureHasFailure(f, @1);
}

@end
