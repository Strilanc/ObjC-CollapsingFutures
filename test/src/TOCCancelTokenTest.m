#import <SenTestingKit/SenTestingKit.h>
#import "TestUtil.h"
#import "TwistedOakCollapsingFutures.h"

@interface TOCCancelTokenTest : SenTestCase
@end

@implementation TOCCancelTokenTest {
@private NSThread* thread;
@private NSRunLoop* runLoop;
}

-(void) setUp {
    thread = [[NSThread alloc] initWithTarget:self selector:@selector(runLoopUntilCancelled) object:nil];
    [thread start];
    
    while (true) {
        @synchronized(self) {
            if (runLoop != nil) break;
        }
    }
}
-(void) runLoopUntilCancelled {
    NSThread* curThread = [NSThread currentThread];
    NSRunLoop* curRunLoop = [NSRunLoop currentRunLoop];
    @synchronized(self) {
        runLoop = curRunLoop;
    }
    while (![curThread isCancelled]) {
        [curRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
}
-(void) tearDown {
    [thread cancel];
}

-(void) testCancelTokenSourceCancel {
    TOCCancelTokenSource* s = [TOCCancelTokenSource new];
    TOCCancelToken* c = s.token;
    test([c canStillBeCancelled]);
    test(![c isAlreadyCancelled]);
    
    [s cancel];
    test([c isAlreadyCancelled]);
    test(![c canStillBeCancelled]);
    
    [s cancel];
    test([c isAlreadyCancelled]);
    test(![c canStillBeCancelled]);
}
-(void) testCancelTokenSourceTryCancel {
    TOCCancelTokenSource* s = [TOCCancelTokenSource new];
    TOCCancelToken* c = s.token;
    test([c canStillBeCancelled]);
    test(![c isAlreadyCancelled]);
    
    test([s tryCancel]);
    test([c isAlreadyCancelled]);
    test(![c canStillBeCancelled]);

    test(![s tryCancel]);
    test([c isAlreadyCancelled]);
    test(![c canStillBeCancelled]);
}
-(void) testImmortalCancelToken {
    TOCCancelToken* c = [TOCCancelToken immortalToken];
    test(![c canStillBeCancelled]);
    test(![c isAlreadyCancelled]);

    [c whenCancelledDo:^{
        test(false);
    }];
}
-(void) testCancelledCancelToken {
    TOCCancelToken* c = [TOCCancelToken cancelledToken];
    test(![c canStillBeCancelled]);
    test([c isAlreadyCancelled]);
    
    __block bool hit = false;
    [c whenCancelledDo:^{
        hit = true;
    }];
    test(hit);
}
-(void) testDeallocSourceResultsInImmortalTokenAndDiscardedCallbacks {
    DeallocCounter* d = [DeallocCounter new];
    
    __block TOCCancelToken* token = nil;
    [TOCFuture futureWithResultFromOperation:^id{
        DeallocCounterHelper* inst = [d makeInstanceToCount];
        
        TOCCancelTokenSource* s = [TOCCancelTokenSource new];
        token = s.token;
        
        // retain inst in closure held by token held by outside
        [s.token whenCancelledDo:^{
            test(false);
            [inst poke];
        }];
        test(d.helperDeallocCount == 0);
        return nil;
    } invokedOnThread:thread];
    
    testUntil(d.helperDeallocCount == 1);
    test(token != nil);
    test(![token isAlreadyCancelled]);
    test(![token canStillBeCancelled]);
}
-(void) testConditionalCancelCallback {
    TOCCancelTokenSource* s = [TOCCancelTokenSource new];
    TOCCancelTokenSource* u = [TOCCancelTokenSource new];
    
    __block int hit1 = 0;
    __block int hit2 = 0;
    [s.token whenCancelledDo:^{
        hit1++;
    } unlessCancelled:u.token];
    [u.token whenCancelledDo:^{
        hit2++;
    } unlessCancelled:s.token];
    
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
    
    __block TOCCancelToken* token1;
    __block TOCCancelToken* token2;
    [TOCFuture futureWithResultFromOperation:^id{
        DeallocCounterHelper* inst1 = [d makeInstanceToCount];
        DeallocCounterHelper* inst2 = [d makeInstanceToCount];
        DeallocCounterHelper* inst3 = [d makeInstanceToCount];
        
        TOCCancelTokenSource* s = [TOCCancelTokenSource new];
        TOCCancelTokenSource* u = [TOCCancelTokenSource new];
        token1 = s.token;
        token2 = u.token;
        
        [s.token whenCancelledDo:^{
            test(false);
            [inst1 poke];
        } unlessCancelled:u.token];
        [u.token whenCancelledDo:^{
            test(false);
            [inst2 poke];
            [inst3 poke];
        } unlessCancelled:s.token];
        test(d.helperDeallocCount == 0);
        return nil;
    } invokedOnThread:thread];
    
    testUntil(d.helperDeallocCount == 3);
    test(token1 != nil);
    test(![token1 isAlreadyCancelled]);
    test(![token1 canStillBeCancelled]);
    test(token2 != nil);
    test(![token2 isAlreadyCancelled]);
    test(![token2 canStillBeCancelled]);
}
-(void) testConditionalCancelCallbackCanDeallocOnCancel {
    DeallocCounter* d = [DeallocCounter new];
    
    __block TOCCancelToken* token1;
    __block TOCCancelToken* token2;
    [TOCFuture futureWithResultFromOperation:^id{
        DeallocCounterHelper* inst1 = [d makeInstanceToCount];
        DeallocCounterHelper* inst2 = [d makeInstanceToCount];
        DeallocCounterHelper* inst3 = [d makeInstanceToCount];
        
        TOCCancelTokenSource* s = [TOCCancelTokenSource new];
        TOCCancelTokenSource* u = [TOCCancelTokenSource new];
        token1 = s.token;
        token2 = u.token;
        
        [s.token whenCancelledDo:^{
            [inst1 poke];
        } unlessCancelled:u.token];
        [u.token whenCancelledDo:^{
            [inst2 poke];
            [inst3 poke];
        } unlessCancelled:s.token];
        test(d.helperDeallocCount == 0);
        
        [s cancel];
        [u cancel];
        return nil;
    } invokedOnThread:thread];
    
    testUntil(d.helperDeallocCount == 3);
    test([token1 isAlreadyCancelled]);
    test([token2 isAlreadyCancelled]);
}
-(void) testConditionalCancelCallbackCanDeallocOnHalfCancelHalfImmortalize {
    DeallocCounter* d = [DeallocCounter new];
    
    __block TOCCancelToken* token1;
    __block TOCCancelToken* token2;
    [TOCFuture futureWithResultFromOperation:^id{
        DeallocCounterHelper* inst1 = [d makeInstanceToCount];
        DeallocCounterHelper* inst2 = [d makeInstanceToCount];
        DeallocCounterHelper* inst3 = [d makeInstanceToCount];
        
        TOCCancelTokenSource* s = [TOCCancelTokenSource new];
        TOCCancelTokenSource* u = [TOCCancelTokenSource new];
        token1 = s.token;
        token2 = u.token;
        
        [s.token whenCancelledDo:^{
            [inst1 poke];
        } unlessCancelled:u.token];
        [u.token whenCancelledDo:^{
            test(false);
            [inst2 poke];
            [inst3 poke];
        } unlessCancelled:s.token];
        test(d.helperDeallocCount == 0);
        
        [s cancel];
        return nil;
    } invokedOnThread:thread];
    
    testUntil(d.helperDeallocCount == 3);
    test(token1 != nil);
    test([token1 isAlreadyCancelled]);
    test(token2 != nil);
    test(![token2 isAlreadyCancelled]);
    test(![token2 canStillBeCancelled]);
}

@end
