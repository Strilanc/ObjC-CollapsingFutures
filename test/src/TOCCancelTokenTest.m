#import "Testing.h"
#import "TwistedOakCollapsingFutures.h"
#import "TOCInternal_BlockObject.h"

@interface TOCCancelTokenTest : SenTestCase
@end

@implementation TOCCancelTokenTest

-(void) testCancelTokenSourceCancel {
    TOCCancelTokenSource* s = [TOCCancelTokenSource new];
    TOCCancelToken* c = s.token;
    test(c.canStillBeCancelled);
    test(!c.isAlreadyCancelled);
    
    [s cancel];
    test(c.isAlreadyCancelled);
    test(!c.canStillBeCancelled);
    
    [s cancel];
    test(c.isAlreadyCancelled);
    test(!c.canStillBeCancelled);
    test(c.state == TOCCancelTokenState_Cancelled);
}
-(void) testCancelTokenSourceTryCancel {
    TOCCancelTokenSource* s = [TOCCancelTokenSource new];
    TOCCancelToken* c = s.token;
    test(c.canStillBeCancelled);
    test(!c.isAlreadyCancelled);
    test(c.state == TOCCancelTokenState_StillCancellable);
    
    test([s tryCancel]);
    test(c.isAlreadyCancelled);
    test(!c.canStillBeCancelled);
    test(c.state == TOCCancelTokenState_Cancelled);
    
    test(![s tryCancel]);
    test(c.isAlreadyCancelled);
    test(!c.canStillBeCancelled);
    test(c.state == TOCCancelTokenState_Cancelled);
}
-(void) testImmortalCancelToken {
    TOCCancelToken* c = TOCCancelToken.immortalToken;
    test(!c.canStillBeCancelled);
    test(!c.isAlreadyCancelled);
    test(c.state == TOCCancelTokenState_Immortal);
    
    testDoesNotHitTarget([c whenCancelledDo:^{
        hitTarget;
    }]);
}
-(void) testCancelledCancelToken {
    TOCCancelToken* c = TOCCancelToken.cancelledToken;
    test(!c.canStillBeCancelled);
    test(c.isAlreadyCancelled);
    test(c.state == TOCCancelTokenState_Cancelled);
    
    __block bool hit = false;
    [c whenCancelledDo:^{
        hit = true;
    }];
    test(hit);
}
-(void) testDeallocSourceResultsInImmortalTokenAndDiscardedCallbacks {
    DeallocCounter* d = [DeallocCounter new];
    
    TOCCancelToken* c = nil;
    @autoreleasepool {
        DeallocToken* dToken = [d makeToken];
        
        TOCCancelTokenSource* s = [TOCCancelTokenSource new];
        c = s.token;
        
        // retain dToken in closure held by token held by outside, so it can't dealloc unless closure deallocs
        [c whenCancelledDo:^{
            test(false);
            [dToken poke];
        }];
        test(d.lostTokenCount == 0);
    }
    
    test(d.lostTokenCount == 1);
    test(c.state == TOCCancelTokenState_Immortal);
}
-(void) testConditionalCancelCallback {
    TOCCancelTokenSource* s = [TOCCancelTokenSource new];
    TOCCancelTokenSource* u = [TOCCancelTokenSource new];
    
    __block int hit1 = 0;
    __block int hit2 = 0;
    [s.token whenCancelledDo:^{
        hit1++;
    } unless:u.token];
    [u.token whenCancelledDo:^{
        hit2++;
    } unless:s.token];
    
    test(hit1 == 0 && hit2 == 0);
    [s cancel];
    test(hit1 == 1);
    test(hit2 == 0);
    [u cancel];
    test(hit1 == 1);
    test(hit2 == 0);
}

-(void) testConditionalCancelCallbackCanDeallocOnImmortalize {
    DeallocCounter* d = [DeallocCounter new];
    
    TOCCancelToken* c1;
    TOCCancelToken* c2;
    @autoreleasepool {
        DeallocToken* dToken1 = [d makeToken];
        DeallocToken* dToken2 = [d makeToken];
        
        TOCCancelTokenSource* s1 = [TOCCancelTokenSource new];
        TOCCancelTokenSource* s2 = [TOCCancelTokenSource new];
        c1 = s1.token;
        c2 = s2.token;
        
        [c1 whenCancelledDo:^{
            test(false);
            [dToken1 poke];
        } unless:c2];
        [c2 whenCancelledDo:^{
            test(false);
            [dToken2 poke];
        } unless:c1];
        test(d.lostTokenCount == 0);
    }
    
    test(d.lostTokenCount == 2);
    test(c1.state == TOCCancelTokenState_Immortal);
    test(c2.state == TOCCancelTokenState_Immortal);
}
-(void) testConditionalCancelCallbackCanDeallocOnCancel {
    DeallocCounter* d = [DeallocCounter new];
    
    TOCCancelToken* c1;
    TOCCancelToken* c2;
    @autoreleasepool {
        DeallocToken* dToken1 = [d makeToken];
        DeallocToken* dToken2 = [d makeToken];
        
        TOCCancelTokenSource* s1 = [TOCCancelTokenSource new];
        TOCCancelTokenSource* s2 = [TOCCancelTokenSource new];
        c1 = s1.token;
        c2 = s2.token;
        
        [c1 whenCancelledDo:^{
            [dToken1 poke];
        } unless:c2];
        [c2 whenCancelledDo:^{
            [dToken2 poke];
        } unless:c1];
        test(d.lostTokenCount == 0);
        
        [s1 cancel];
        [s2 cancel];
    }
    
    test(d.lostTokenCount == 2);
    test(c1.isAlreadyCancelled);
    test(c2.isAlreadyCancelled);
}
-(void) testDealloc_AfterCancel {
    DeallocCounter* d = [DeallocCounter new];
    TOCCancelTokenSource* s;
    @autoreleasepool {
        s = [TOCCancelTokenSource new];
        DeallocToken* dToken = [d makeToken];
        [s.token whenCancelledDo:^{
            [dToken poke];
        }];
        [s cancel];
    }
    test(d.lostTokenCount == 1);
    test(s != nil);
}

-(void) testConditionalCancelCallbackCanDeallocOnHalfCancelHalfImmortalize {
    DeallocCounter* d = [DeallocCounter new];
    
    TOCCancelToken* c1;
    TOCCancelToken* c2;
    @autoreleasepool {
        DeallocToken* dToken1 = [d makeToken];
        DeallocToken* dToken2 = [d makeToken];
        
        TOCCancelTokenSource* s1 = [TOCCancelTokenSource new];
        TOCCancelTokenSource* s2 = [TOCCancelTokenSource new];
        c1 = s1.token;
        c2 = s2.token;
        
        [c1 whenCancelledDo:^{
            [dToken1 poke];
        } unless:c2];
        [c2 whenCancelledDo:^{
            test(false);
            [dToken2 poke];
        } unless:c1];
        test(d.lostTokenCount == 0);
        
        [s1 cancel];
    }

    test(d.lostTokenCount == 2);
    test(c1.isAlreadyCancelled);
    test(!c2.isAlreadyCancelled);
    test(!c2.canStillBeCancelled);
}

-(void) testSelfOnCancelledUnlesCancelledIsConsistentBeforeAndAfter {
    TOCCancelTokenSource* s = [TOCCancelTokenSource new];
    
    __block int hit1 = 0;
    [s.token whenCancelledDo:^{
        hit1++;
    } unless:s.token];
    
    [s cancel];
    
    __block int hit2 = 0;
    [s.token whenCancelledDo:^{
        hit2++;
    } unless:s.token];
    
    test(hit1 <= 1);
    test(hit2 <= 1);
    test(hit1 == hit2);
}

-(void) testOnCancelledUnlesCancelledWhenBothCancelledDoesNotRunCallback {
    __block int hit1 = 0;
    [TOCCancelToken.cancelledToken whenCancelledDo:^{
        hit1++;
    } unless:TOCCancelToken.cancelledToken];
    test(hit1 == 0);
}

-(void) testCancelTokenSourceUntil {
    TOCCancelTokenSource* s = [TOCCancelTokenSource new];
    TOCCancelTokenSource* d = [TOCCancelTokenSource cancelTokenSourceUntil:s.token];
    test(s.token.state == TOCCancelTokenState_StillCancellable);
    test(d.token.state == TOCCancelTokenState_StillCancellable);
    
    [s cancel];
    test(s.token.state == TOCCancelTokenState_Cancelled);
    test(d.token.state == TOCCancelTokenState_Cancelled);
}
-(void) testCancelTokenSourceUntil_Reverse {
    TOCCancelTokenSource* s = [TOCCancelTokenSource new];
    TOCCancelTokenSource* d = [TOCCancelTokenSource cancelTokenSourceUntil:s.token];
    test(s.token.state == TOCCancelTokenState_StillCancellable);
    test(d.token.state == TOCCancelTokenState_StillCancellable);
    
    [d cancel];
    test(s.token.state == TOCCancelTokenState_StillCancellable);
    test(d.token.state == TOCCancelTokenState_Cancelled);
}
-(void) testCancelTokenSourceUntil_CleansUpEagerly {
    TOCCancelTokenSource* s = [TOCCancelTokenSource new];
    vm_size_t memoryBefore = peekAllocatedMemoryInBytes();
    int repeats     = 10000;
    vm_size_t slack = 50000;
    for (int i = 0; i < repeats; i++) {
        @autoreleasepool {
            TOCCancelTokenSource* d = [TOCCancelTokenSource cancelTokenSourceUntil:s.token];
            [d cancel];
        }
    }
    vm_size_t memoryAfter = peekAllocatedMemoryInBytes();
    bool likelyIsNotCleaningUp = memoryAfter > memoryBefore + slack;
    test(!likelyIsNotCleaningUp);
}

-(void) testFutureSourceUntil {
    TOCCancelTokenSource* s = [TOCCancelTokenSource new];
    TOCFutureSource* d = [TOCFutureSource futureSourceUntil:s.token];
    test(s.token.state == TOCCancelTokenState_StillCancellable);
    test(d.future.state == TOCFutureState_AbleToBeSet);
    
    [s cancel];
    test(s.token.state == TOCCancelTokenState_Cancelled);
    test(d.future.hasFailedWithCancel);
}
-(void) testFutureSourceUntil_Reverse {
    TOCCancelTokenSource* s = [TOCCancelTokenSource new];
    TOCFutureSource* d = [TOCFutureSource futureSourceUntil:s.token];
    test(s.token.state == TOCCancelTokenState_StillCancellable);
    test(d.future.state == TOCFutureState_AbleToBeSet);
    
    [d trySetResult:nil];
    test(s.token.state == TOCCancelTokenState_StillCancellable);
    test(d.future.state == TOCFutureState_CompletedWithResult);
}
-(void) testFutureSourceUntil_CleansUpEagerly {
    TOCCancelTokenSource* s = [TOCCancelTokenSource new];
    vm_size_t memoryBefore = peekAllocatedMemoryInBytes();
    int repeats     = 10000;
    vm_size_t slack = 50000;
    for (int i = 0; i < repeats; i++) {
        @autoreleasepool {
            TOCFutureSource* d = [TOCFutureSource futureSourceUntil:s.token];
            [d trySetResult:nil];
        }
    }
    vm_size_t memoryAfter = peekAllocatedMemoryInBytes();
    bool likelyIsNotCleaningUp = memoryAfter > memoryBefore + slack;
    test(!likelyIsNotCleaningUp);
}

-(void) testWhenCancelledDo_StaysOnMainThread {
    TOCCancelTokenSource* c2 = [TOCCancelTokenSource new];
    dispatch_after(DISPATCH_TIME_NOW, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        TOCCancelTokenSource* c1 = [TOCCancelTokenSource new];
        TOCFuture* f = [TOCFuture futureWithResultFromOperation:^id{
            test([NSThread isMainThread]);
            [c1.token whenCancelledDo:^{
                test([NSThread isMainThread]);
                [c2 cancel];
            }];
            return nil;
        } invokedOnThread:[NSThread mainThread]];
        
        test(![NSThread isMainThread]);
        testCompletesConcurrently(f);
        testFutureHasResult(f, nil);
        test(c2.token.state == TOCCancelTokenState_StillCancellable);
        
        [c1 cancel];
    });
    
    for (int i = 0; i < 5 && !c2.token.isAlreadyCancelled; i++) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    test(c2.token.state == TOCCancelTokenState_Cancelled);
}
-(void) testWhenCancelledDoUnless_StaysOnMainThread {
    TOCCancelTokenSource* c2 = [TOCCancelTokenSource new];
    dispatch_after(DISPATCH_TIME_NOW, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        TOCCancelTokenSource* c1 = [TOCCancelTokenSource new];
        TOCFuture* f = [TOCFuture futureWithResultFromOperation:^id{
            test([NSThread isMainThread]);
            [c1.token whenCancelledDo:^{
                test([NSThread isMainThread]);
                [c2 cancel];
            } unless:c2.token];
            return nil;
        } invokedOnThread:[NSThread mainThread]];
        
        test(![NSThread isMainThread]);
        testCompletesConcurrently(f);
        testFutureHasResult(f, nil);
        test(c2.token.state == TOCCancelTokenState_StillCancellable);
        
        [c1 cancel];
    });
    
    for (int i = 0; i < 5 && !c2.token.isAlreadyCancelled; i++) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    test(c2.token.state == TOCCancelTokenState_Cancelled);
}

-(void) testWhenCancelledDoUnless_AfterTheFactCancellationStillStopsCallbacksOnMainThread {
    TOCCancelTokenSource* s1 = [TOCCancelTokenSource new];
    TOCCancelTokenSource* s2 = [TOCCancelTokenSource new];

    test([NSThread isMainThread]);
    __block int hits = 0;
    for (int i = 0; i < 5; i++) {
        [s1.token whenCancelledDo:^{
            [s2 cancel];
            hits += 1;
        } unless:s2.token];
    }
    
    test(hits == 0);
    [s1 cancel];
    test(hits == 1);
}
-(void) testWhenCancelledDoUnless_AfterTheFactCancellationStillStopsCallbacksOnMainThread_SecondThread {
    TOCCancelTokenSource* s1 = [TOCCancelTokenSource new];
    TOCCancelTokenSource* s2 = [TOCCancelTokenSource new];
    
    test([NSThread isMainThread]);
    __block int hits = 0;
    for (int i = 0; i < 5; i++) {
        [s1.token whenCancelledDo:^{
            test([NSThread isMainThread]);
            [s2 cancel];
            hits += 1;
        } unless:s2.token];
    }
    
    test(hits == 0);
    [TOCInternal_BlockObject performBlockOnNewThread:^{[s1 cancel];}];
    for (int i = 0; i < 10; i++) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    test(hits == 1);
}

@end
