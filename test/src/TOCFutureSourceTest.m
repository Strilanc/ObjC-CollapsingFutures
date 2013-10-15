#import <SenTestingKit/SenTestingKit.h>

#import "TOCFutureMoreContinuations.h"
#import "TestUtil.h"

@interface TOCFutureSourceTest : SenTestCase
@end

@implementation TOCFutureSourceTest

-(void)testFailedFutureSource {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCFuture* f = s.future;
    test([s trySetFailure:@"X"]);
    
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
    TOCFutureSource* s = [TOCFutureSource new];
    TOCFuture* f = s.future;
    test([s trySetResult:@"X"]);
    
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
    TOCFutureSource* s = [TOCFutureSource new];
    TOCFuture* f = s.future;
    
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
    TOCFutureSource* s = [TOCFutureSource new];
    TOCFuture* f = s.future;
    test([s trySetResult:[TOCFuture futureWithFailure:@"X"]]);
    
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
    TOCFutureSource* s = [TOCFutureSource new];
    TOCFuture* f = s.future;
    test([s trySetResult:[TOCFuture futureWithResult:@"X"]]);
    
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
    TOCFutureSource* s = [TOCFutureSource new];
    TOCFuture* f = s.future;
    test([s trySetResult:[TOCFutureSource new].future]);
    
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
    TOCFutureSource* s = [TOCFutureSource new];
    TOCFuture* f = s.future;
    test([s trySetResult:f]);
    test([f isIncomplete]);
}
-(void)testCyclicCollapsedFutureAllowsDealloc {
    TOCFutureSource* s = [TOCFutureSource new];
    TOCFuture* f = s.future;
    DeallocCounter* d = [DeallocCounter new];
    @autoreleasepool {
        DeallocToken* dToken = [d makeToken];
        [f finallyDo:^(TOCFuture *completed) {
            [dToken poke];
        }];
        test(d.lostTokenCount == 0);
        [s trySetResult:f];
    }
    test(d.lostTokenCount == 1);
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
    [f trySetResult:g.future];
    test([f.future isIncomplete]);
    [g trySetResult:@1];
    testFutureHasResult(f.future, @1);
}
-(void)testDeferredFailTrySet {
    TOCFutureSource* f = [TOCFutureSource new];
    TOCFutureSource* g = [TOCFutureSource new];
    [f trySetResult:g.future];
    test([f.future isIncomplete]);
    [g trySetFailure:@1];
    testFutureHasFailure(f.future, @1);
}
-(void) testForceSetResult {
    TOCFutureSource* f = [TOCFutureSource new];
    [f forceSetResult:@1];
    testThrows([f forceSetResult:@1]);
    testThrows([f forceSetResult:@2]);
    testThrows([f forceSetFailure:@3]);
}
-(void) testForceSetFailure {
    TOCFutureSource* f = [TOCFutureSource new];
    [f forceSetFailure:@1];
    testThrows([f forceSetResult:@1]);
    testThrows([f forceSetResult:@2]);
    testThrows([f forceSetFailure:@3]);
}

@end
