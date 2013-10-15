#import <SenTestingKit/SenTestingKit.h>
#import "TestUtil.h"
#import "TwistedOakCollapsingFutures.h"

@interface TOCCancelTokenTest : SenTestCase
@end

@implementation TOCCancelTokenTest

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
    test(![c isAlreadyCancelled]);
    test(![c canStillBeCancelled]);
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
    test(![c1 isAlreadyCancelled]);
    test(![c1 canStillBeCancelled]);
    test(![c2 isAlreadyCancelled]);
    test(![c2 canStillBeCancelled]);
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
    test([c1 isAlreadyCancelled]);
    test([c2 isAlreadyCancelled]);
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
    test([c1 isAlreadyCancelled]);
    test(![c2 isAlreadyCancelled]);
    test(![c2 canStillBeCancelled]);
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
    [[TOCCancelToken cancelledToken] whenCancelledDo:^{
        hit1++;
    } unless:[TOCCancelToken cancelledToken]];
    test(hit1 == 0);
}

@end
