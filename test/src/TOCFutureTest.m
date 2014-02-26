#import "Testing.h"
#import "TwistedOakCollapsingFutures.h"

@interface TOCFutureTest : SenTestCase
@end

@implementation TOCFutureTest

-(void)testFailedFuture {
    TOCFuture* f = [TOCFuture futureWithFailure:@"X"];
    
    test(!f.isIncomplete);
    test(f.hasFailed);
    test(!f.hasResult);
    test([f.forceGetFailure isEqual:@"X"]);
    testThrows(f.forceGetResult);
    test(f.description != nil);
    test(f.state == TOCFutureState_Failed);
    
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
    
    test(!f.isIncomplete);
    test(!f.hasFailed);
    test(f.hasResult);
    test([f.forceGetResult isEqual:@"X"]);
    testThrows(f.forceGetFailure);
    test(f.description != nil);
    test(f.state == TOCFutureState_CompletedWithResult);
    
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
    test([[TOCFutureSource new].future finally:^id(TOCFuture* completed) { return @1; } unless:nil].isIncomplete);
    testFutureHasResult([[TOCFuture futureWithResult:@7] finally:^id(TOCFuture* completed) { return @2; } unless:nil], @2);
    testFutureHasResult([[TOCFuture futureWithFailure:@8] finally:^id(TOCFuture* completed) { return @3; } unless:nil], @3);
    
    TOCCancelTokenSource* c = [TOCCancelTokenSource new];
    testDoesNotHitTarget([[TOCFutureSource new].future finally:^id(TOCFuture* completed) { hitTarget; return nil; } unless:c.token]);
    testHitsTarget([[TOCFuture futureWithResult:@7] finally:^id(TOCFuture* completed) { testFutureHasResult(completed, @7); hitTarget; return nil; } unless:c.token]);
    testHitsTarget([[TOCFuture futureWithFailure:@8] finally:^id(TOCFuture* completed) { testFutureHasFailure(completed, @8); hitTarget; return nil; } unless:c.token]);
    test([[TOCFutureSource new].future finally:^id(TOCFuture* completed) { return @1; } unless:c.token].isIncomplete);
    testFutureHasResult([[TOCFuture futureWithResult:@7] finally:^id(TOCFuture* completed) { return @2; } unless:c.token], @2);
    testFutureHasResult([[TOCFuture futureWithFailure:@8] finally:^id(TOCFuture* completed) { return @3; } unless:c.token], @3);
    
    [c cancel];
    testDoesNotHitTarget([[TOCFutureSource new].future finally:^id(TOCFuture* completed) { hitTarget; return nil; } unless:c.token]);
    testDoesNotHitTarget([[TOCFuture futureWithResult:@7] finally:^id(TOCFuture* completed) { hitTarget; return nil; } unless:c.token]);
    testDoesNotHitTarget([[TOCFuture futureWithFailure:@8] finally:^id(TOCFuture* completed) { hitTarget; return nil; } unless:c.token]);
    test([[TOCFutureSource new].future finally:^id(TOCFuture* completed) { return @1; } unless:c.token].hasFailedWithCancel);
    test([[TOCFuture futureWithResult:@7] finally:^id(TOCFuture* completed) { return @2; } unless:c.token].hasFailedWithCancel);
    test([[TOCFuture futureWithFailure:@8] finally:^id(TOCFuture* completed) { return @3; } unless:c.token].hasFailedWithCancel);
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
    test([[TOCFutureSource new].future then:^id(id result) { return @1; } unless:nil].isIncomplete);
    testFutureHasResult([[TOCFuture futureWithResult:@7] then:^id(id result) { return @2; } unless:nil], @2);
    testFutureHasFailure([[TOCFuture futureWithFailure:@8] then:^id(id result) { return @3; } unless:nil], @8);
    
    TOCCancelTokenSource* c = [TOCCancelTokenSource new];
    testDoesNotHitTarget([[TOCFutureSource new].future then:^id(id result) { hitTarget; return nil; } unless:c.token]);
    testHitsTarget([[TOCFuture futureWithResult:@7] then:^id(id result) { test([result isEqual:@7]); hitTarget; return nil; } unless:c.token]);
    testDoesNotHitTarget([[TOCFuture futureWithFailure:@8] then:^id(id result) { hitTarget; return nil; } unless:c.token]);
    test([[TOCFutureSource new].future then:^id(id result) { return @1; } unless:c.token].isIncomplete);
    testFutureHasResult([[TOCFuture futureWithResult:@7] then:^id(id result) { return @2; } unless:c.token], @2);
    testFutureHasFailure([[TOCFuture futureWithFailure:@8] then:^id(id result) { return @3; } unless:c.token], @8);
    
    [c cancel];
    testDoesNotHitTarget([[TOCFutureSource new].future then:^id(id result) { hitTarget; return nil; } unless:c.token]);
    testDoesNotHitTarget([[TOCFuture futureWithResult:@7] then:^id(id result) { hitTarget; return nil; } unless:c.token]);
    testDoesNotHitTarget([[TOCFuture futureWithFailure:@8] then:^id(id result) { hitTarget; return nil; } unless:c.token]);
    test([[TOCFutureSource new].future then:^id(id result) { return @1; } unless:c.token].hasFailedWithCancel);
    test([[TOCFuture futureWithResult:@7] then:^id(id result) { return @2; } unless:c.token].hasFailedWithCancel);
    test([[TOCFuture futureWithFailure:@8] then:^id(id result) { return @3; } unless:c.token].hasFailedWithCancel);
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
    test([[TOCFutureSource new].future catch:^id(id failure) { return @1; } unless:nil].isIncomplete);
    testFutureHasResult([[TOCFuture futureWithResult:@7] catch:^id(id failure) { return @2; } unless:nil], @7);
    testFutureHasResult([[TOCFuture futureWithFailure:@8] catch:^id(id failure) { return @3; } unless:nil], @3);
    
    TOCCancelTokenSource* c = [TOCCancelTokenSource new];
    testDoesNotHitTarget([[TOCFutureSource new].future catch:^id(id failure) { hitTarget; return nil; } unless:c.token]);
    testDoesNotHitTarget([[TOCFuture futureWithResult:@7] catch:^id(id failure) { hitTarget; return nil; } unless:c.token]);
    testHitsTarget([[TOCFuture futureWithFailure:@8] catch:^id(id failure) { test([failure isEqual:@8]); hitTarget; return nil; } unless:c.token]);
    test([[TOCFutureSource new].future catch:^id(id failure) { return @1; } unless:c.token].isIncomplete);
    testFutureHasResult([[TOCFuture futureWithResult:@7] catch:^id(id failure) { return @2; } unless:c.token], @7);
    testFutureHasResult([[TOCFuture futureWithFailure:@8] catch:^id(id failure) { return @3; } unless:c.token], @3);
    
    [c cancel];
    testDoesNotHitTarget([[TOCFutureSource new].future catch:^id(id failure) { hitTarget; return nil; } unless:c.token]);
    testDoesNotHitTarget([[TOCFuture futureWithResult:@7] catch:^id(id failure) { hitTarget; return nil; } unless:c.token]);
    testDoesNotHitTarget([[TOCFuture futureWithFailure:@8] catch:^id(id failure) { hitTarget; return nil; } unless:c.token]);
    test([[TOCFutureSource new].future catch:^id(id failure) { return @1; } unless:c.token].hasFailedWithCancel);
    test([[TOCFuture futureWithResult:@7] catch:^id(id failure) { return @2; } unless:c.token].hasFailedWithCancel);
    test([[TOCFuture futureWithFailure:@8] catch:^id(id failure) { return @3; } unless:c.token].hasFailedWithCancel);
}

-(void) testFinallyDo_StaysOnMainThread {
    TOCCancelTokenSource* c2 = [TOCCancelTokenSource new];
    dispatch_after(DISPATCH_TIME_NOW, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        TOCFutureSource* c1 = [TOCFutureSource new];
        TOCFuture* f = [TOCFuture futureFromOperation:^id{
            test([NSThread isMainThread]);
            [c1.future finallyDo:^(TOCFuture* completed){
                test([NSThread isMainThread]);
                [c2 cancel];
            } unless:c2.token];
            return nil;
        } invokedOnThread:[NSThread mainThread]];
        
        test(![NSThread isMainThread]);
        testCompletesConcurrently(f);
        testFutureHasResult(f, nil);
        test(c2.token.state == TOCCancelTokenState_StillCancellable);
        
        [c1 trySetResult:nil];
    });
    
    for (int i = 0; i < 5 && !c2.token.isAlreadyCancelled; i++) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    test(c2.token.state == TOCCancelTokenState_Cancelled);
}

-(void)testFutureEquality_viaObject {
    TOCFuture* fres = [TOCFuture futureWithResult:@1];
    TOCFuture* ferr = [TOCFuture futureWithFailure:@1];
    TOCFuture* fimm = [TOCFutureSource new].future;
    test(fimm.state == TOCFutureState_Immortal);
    TOCFutureSource* sinc = [TOCFutureSource new];
    TOCFuture* finc = sinc.future;
    TOCFutureSource* slat = [TOCFutureSource new];
    [slat forceSetResult:finc];
    TOCFuture* flat = slat.future;
    
    // result
    test([fres isEqual:fres]);
    test([fres isEqual:[TOCFuture futureWithResult:@1]]);
    test(fres.hash == [TOCFuture futureWithResult:@1].hash);
    test([fres isEqual:[TOCFuture futureWithResult:fres]]);
    test(fres.hash == [TOCFuture futureWithResult:fres].hash);
    test(![fres isEqual:[TOCFuture futureWithFailure:fres]]);
    test(![fres isEqual:[TOCFuture futureWithResult:@2]]);
    test(![fres isEqual:ferr]);
    test(![fres isEqual:fimm]);
    test(![fres isEqual:finc]);
    test(![fres isEqual:sinc]);
    test(![fres isEqual:flat]);
    test(![fres isEqual:nil]);
    test(![fres isEqual:@1]);
    test(![fres isEqual:@[]]);
    
    // error
    test([ferr isEqual:ferr]);
    test([ferr isEqual:[TOCFuture futureWithFailure:@1]]);
    test(ferr.hash == [TOCFuture futureWithFailure:@1].hash);
    test([ferr isEqual:[TOCFuture futureWithResult:ferr]]);
    test(ferr.hash == [TOCFuture futureWithResult:ferr].hash);
    test(![ferr isEqual:[TOCFuture futureWithFailure:ferr]]);
    test(![ferr isEqual:[TOCFuture futureWithFailure:@2]]);
    test(![ferr isEqual:fres]);
    test(![ferr isEqual:fimm]);
    test(![ferr isEqual:finc]);
    test(![ferr isEqual:sinc]);
    test(![ferr isEqual:flat]);
    test(![ferr isEqual:nil]);
    test(![ferr isEqual:@1]);
    test(![ferr isEqual:@[]]);

    // immortal
    TOCFuture* imm2 = [TOCFutureSource new].future;
    test(imm2.state == TOCFutureState_Immortal);
    test([fimm isEqual:fimm]);
    test([fimm isEqual:imm2]);
    test(fimm.hash == imm2.hash);
    test([fimm isEqual:[TOCFuture futureWithResult:fimm]]);
    test(fimm.hash == [TOCFuture futureWithResult:fimm].hash);
    test(![fimm isEqual:[TOCFuture futureWithFailure:fimm]]);
    test(![fimm isEqual:ferr]);
    test(![fimm isEqual:fres]);
    test(![fimm isEqual:finc]);
    test(![fimm isEqual:sinc]);
    test(![fimm isEqual:flat]);
    test(![fimm isEqual:nil]);
    test(![fimm isEqual:@1]);
    test(![fimm isEqual:@[]]);

    // incomplete
    TOCFutureSource* sinc2 = [TOCFutureSource new];
    TOCFuture* finc2 = sinc2.future;
    test([finc isEqual:finc]);
    test([finc isEqual:[TOCFuture futureWithResult:finc]]); // due to returning argument
    test(![finc isEqual:finc2]);
    test(![finc isEqual:[TOCFuture futureWithFailure:finc]]);
    test(![finc isEqual:ferr]);
    test(![finc isEqual:fres]);
    test(![finc isEqual:fimm]);
    test(![finc isEqual:sinc]);
    test(![finc isEqual:flat]);
    test(![finc isEqual:nil]);
    test(![finc isEqual:@1]);
    test(![finc isEqual:@[]]);

    // flattening
    test([flat isEqual:flat]);
    test([flat isEqual:[TOCFuture futureWithResult:flat]]); // due to returning argument
    test(![flat isEqual:finc2]);
    test(![flat isEqual:[TOCFuture futureWithFailure:fimm]]);
    test(![flat isEqual:ferr]);
    test(![flat isEqual:fres]);
    // (flat vs finc not specified due to efficiency issues keeping dependencies flattened)
    test(![flat isEqual:sinc]);
    test(![flat isEqual:fimm]);
    test(![flat isEqual:nil]);
    test(![flat isEqual:@1]);
    test(![flat isEqual:@[]]);

    // after completion
    [sinc forceSetResult:@2];
    test([finc isEqual:[TOCFuture futureWithResult:@2]]);
    test(finc.hash == [TOCFuture futureWithResult:@2].hash);
    [sinc2 forceSetFailure:@3];
    test([finc2 isEqual:[TOCFuture futureWithFailure:@3]]);
    test(finc2.hash == [TOCFuture futureWithFailure:@3].hash);

    // nil value
    test([[TOCFuture futureWithResult:nil] isEqual:[TOCFuture futureWithResult:nil]]);
    test(![[TOCFuture futureWithResult:nil] isEqual:[TOCFuture futureWithResult:@1]]);
    test(![[TOCFuture futureWithResult:@1] isEqual:[TOCFuture futureWithResult:nil]]);
    test([[TOCFuture futureWithFailure:nil] isEqual:[TOCFuture futureWithFailure:nil]]);
    test(![[TOCFuture futureWithFailure:nil] isEqual:[TOCFuture futureWithFailure:@1]]);
    test(![[TOCFuture futureWithFailure:@1] isEqual:[TOCFuture futureWithFailure:nil]]);
}

-(void)testFutureEquality_direct {
    TOCFuture* fres = [TOCFuture futureWithResult:@1];
    TOCFuture* ferr = [TOCFuture futureWithFailure:@1];
    TOCFuture* fimm = [TOCFutureSource new].future;
    test(fimm.state == TOCFutureState_Immortal);
    TOCFutureSource* sinc = [TOCFutureSource new];
    TOCFuture* finc = sinc.future;
    TOCFutureSource* slat = [TOCFutureSource new];
    [slat forceSetResult:finc];
    TOCFuture* flat = slat.future;
    
    // result
    test([fres isEqualToFuture:fres]);
    test([fres isEqualToFuture:[TOCFuture futureWithResult:@1]]);
    test([fres isEqualToFuture:[TOCFuture futureWithResult:fres]]);
    test(![fres isEqualToFuture:[TOCFuture futureWithFailure:fres]]);
    test(![fres isEqualToFuture:[TOCFuture futureWithResult:@2]]);
    test(![fres isEqualToFuture:ferr]);
    test(![fres isEqualToFuture:fimm]);
    test(![fres isEqualToFuture:finc]);
    test(![fres isEqualToFuture:flat]);
    test(![fres isEqualToFuture:nil]);
    
    // error
    test([ferr isEqualToFuture:ferr]);
    test([ferr isEqualToFuture:[TOCFuture futureWithFailure:@1]]);
    test([ferr isEqualToFuture:[TOCFuture futureWithResult:ferr]]);
    test(![ferr isEqualToFuture:[TOCFuture futureWithFailure:ferr]]);
    test(![ferr isEqualToFuture:[TOCFuture futureWithFailure:@2]]);
    test(![ferr isEqualToFuture:fres]);
    test(![ferr isEqualToFuture:fimm]);
    test(![ferr isEqualToFuture:finc]);
    test(![ferr isEqualToFuture:flat]);
    test(![ferr isEqualToFuture:nil]);
    
    // immortal
    TOCFuture* imm2 = [TOCFutureSource new].future;
    test(imm2.state == TOCFutureState_Immortal);
    test([fimm isEqualToFuture:fimm]);
    test([fimm isEqualToFuture:imm2]);
    test(fimm.hash == imm2.hash);
    test([fimm isEqualToFuture:[TOCFuture futureWithResult:fimm]]);
    test(fimm.hash == [TOCFuture futureWithResult:fimm].hash);
    test(![fimm isEqualToFuture:[TOCFuture futureWithFailure:fimm]]);
    test(![fimm isEqualToFuture:ferr]);
    test(![fimm isEqualToFuture:fres]);
    test(![fimm isEqualToFuture:finc]);
    test(![fimm isEqualToFuture:flat]);
    test(![fimm isEqualToFuture:nil]);
    
    // incomplete
    TOCFutureSource* sinc2 = [TOCFutureSource new];
    TOCFuture* finc2 = sinc2.future;
    test([finc isEqualToFuture:finc]);
    test([finc isEqualToFuture:[TOCFuture futureWithResult:finc]]); // due to returning argument
    test(![finc isEqualToFuture:finc2]);
    test(![finc isEqualToFuture:[TOCFuture futureWithFailure:finc]]);
    test(![finc isEqualToFuture:ferr]);
    test(![finc isEqualToFuture:fres]);
    test(![finc isEqualToFuture:fimm]);
    test(![finc isEqualToFuture:flat]);
    test(![finc isEqualToFuture:nil]);
    
    // flattening
    test([flat isEqualToFuture:flat]);
    test([flat isEqualToFuture:[TOCFuture futureWithResult:flat]]); // due to returning argument
    test(![flat isEqualToFuture:finc2]);
    test(![flat isEqualToFuture:[TOCFuture futureWithFailure:fimm]]);
    test(![flat isEqualToFuture:ferr]);
    test(![flat isEqualToFuture:fres]);
    // (flat vs finc not specified due to efficiency issues keeping dependencies flattened)
    test(![flat isEqualToFuture:fimm]);
    test(![flat isEqualToFuture:nil]);
    
    // after completion
    // note: complete differently lest the above comparison be technically implementation defined
    [sinc forceSetResult:@2];
    [sinc2 forceSetFailure:@3];
    test([finc isEqualToFuture:[TOCFuture futureWithResult:@2]]);
    test(finc.hash == [TOCFuture futureWithResult:@2].hash);
    test([finc2 isEqualToFuture:[TOCFuture futureWithFailure:@3]]);
    test(finc2.hash == [TOCFuture futureWithFailure:@3].hash);
    
    // nil value
    test([[TOCFuture futureWithResult:nil] isEqualToFuture:[TOCFuture futureWithResult:nil]]);
    test(![[TOCFuture futureWithResult:nil] isEqualToFuture:[TOCFuture futureWithResult:@1]]);
    test(![[TOCFuture futureWithResult:@1] isEqualToFuture:[TOCFuture futureWithResult:nil]]);
    test([[TOCFuture futureWithFailure:nil] isEqualToFuture:[TOCFuture futureWithFailure:nil]]);
    test(![[TOCFuture futureWithFailure:nil] isEqualToFuture:[TOCFuture futureWithFailure:@1]]);
    test(![[TOCFuture futureWithFailure:@1] isEqualToFuture:[TOCFuture futureWithFailure:nil]]);
}

@end
