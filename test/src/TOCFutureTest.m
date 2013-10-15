#import <SenTestingKit/SenTestingKit.h>

#import "TOCFuture.h"
#import "TOCFutureMoreContinuations.h"
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

-(void) testFinallyDoUnless_Immediate {
    testHitsTarget([[TOCFuture futureWithResult:@1] finallyDo:^(TOCFuture *completed) {
        hitTarget;
        testFutureHasResult(completed, @1);
    } unless:nil]);
    
    TOCCancelTokenSource* c = [TOCCancelTokenSource new];
    
    testHitsTarget([[TOCFuture futureWithResult:@2] finallyDo:^(TOCFuture *completed) {
        hitTarget;
        testFutureHasResult(completed, @2);
    } unless:c.token]);
    
    testHitsTarget([[TOCFuture futureWithFailure:@-1] finallyDo:^(TOCFuture *completed) {
        hitTarget;
        testFutureHasFailure(completed, @-1);
    } unless:c.token]);
    
    [c cancel];
    
    testDoesNotHitTarget([[TOCFuture futureWithResult:@2] finallyDo:^(TOCFuture *completed) {
        hitTarget;
        test(false);
    } unless:c.token]);
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

@end
