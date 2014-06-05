#import "Testing.h"
#import "TOCCancelToken+MoreConstructors.h"

@interface TOCCancelToken_MoreConstructorsTest : XCTestCase
@end

@implementation TOCCancelToken_MoreConstructorsTest

-(void)testMatchFirstToCancel_SpecialCasesAreOptimized {
    TOCCancelTokenSource* s = [TOCCancelTokenSource new];
    test([TOCCancelToken matchFirstToCancelBetween:TOCCancelToken.cancelledToken and:TOCCancelToken.cancelledToken].isAlreadyCancelled);
    test([TOCCancelToken matchLastToCancelBetween:TOCCancelToken.immortalToken and:TOCCancelToken.immortalToken].state == TOCCancelTokenState_Immortal);
    test([TOCCancelToken matchFirstToCancelBetween:s.token and:TOCCancelToken.cancelledToken].isAlreadyCancelled);
    test([TOCCancelToken matchFirstToCancelBetween:s.token and:TOCCancelToken.immortalToken] == s.token);
    test([TOCCancelToken matchFirstToCancelBetween:TOCCancelToken.cancelledToken and:s.token].isAlreadyCancelled);
    test([TOCCancelToken matchFirstToCancelBetween:TOCCancelToken.immortalToken and:s.token] == s.token);
    test([TOCCancelToken matchFirstToCancelBetween:s.token and:s.token] == s.token);
}
-(void)testMatchFirstToCancel_Cancel {
    TOCCancelTokenSource* s1 = [TOCCancelTokenSource new];
    TOCCancelTokenSource* s2 = [TOCCancelTokenSource new];
    TOCCancelToken* c1 = [TOCCancelToken matchFirstToCancelBetween:s1.token and:s2.token];
    TOCCancelToken* c2 = [TOCCancelToken matchFirstToCancelBetween:s1.token and:s2.token];
    
    test(c1.state == TOCCancelTokenState_StillCancellable);
    test(c2.state == TOCCancelTokenState_StillCancellable);
    
    [s1 cancel];
    
    test(c1.state == TOCCancelTokenState_Cancelled);
    test(c2.state == TOCCancelTokenState_Cancelled);
}
-(void)testMatchFirstToCancel_Immortal {
    TOCCancelToken* c1;
    TOCCancelToken* c2;
    @autoreleasepool {
        TOCCancelTokenSource* s1 = [TOCCancelTokenSource new];
        @autoreleasepool {
            TOCCancelTokenSource* s2 = [TOCCancelTokenSource new];
            c1 = [TOCCancelToken matchFirstToCancelBetween:s1.token and:s2.token];
            c2 = [TOCCancelToken matchFirstToCancelBetween:s1.token and:s2.token];
            
            test(c1.state == TOCCancelTokenState_StillCancellable);
            test(c2.state == TOCCancelTokenState_StillCancellable);
        }
        
        test(c1.state == TOCCancelTokenState_StillCancellable);
        test(c2.state == TOCCancelTokenState_StillCancellable);
    }
    
    test(c1.state == TOCCancelTokenState_Immortal);
    test(c2.state == TOCCancelTokenState_Immortal);
}

-(void)testMatchLastToCancel_SpecialCasesAreOptimized {
    TOCCancelTokenSource* s = [TOCCancelTokenSource new];
    test([TOCCancelToken matchLastToCancelBetween:TOCCancelToken.cancelledToken and:TOCCancelToken.cancelledToken].isAlreadyCancelled);
    test([TOCCancelToken matchLastToCancelBetween:TOCCancelToken.immortalToken and:TOCCancelToken.immortalToken].state == TOCCancelTokenState_Immortal);
    test([TOCCancelToken matchLastToCancelBetween:s.token and:TOCCancelToken.cancelledToken] == s.token);
    test([TOCCancelToken matchLastToCancelBetween:s.token and:TOCCancelToken.immortalToken].state == TOCCancelTokenState_Immortal);
    test([TOCCancelToken matchLastToCancelBetween:TOCCancelToken.cancelledToken and:s.token] == s.token);
    test([TOCCancelToken matchLastToCancelBetween:TOCCancelToken.immortalToken and:s.token].state == TOCCancelTokenState_Immortal);
    test([TOCCancelToken matchLastToCancelBetween:s.token and:s.token] == s.token);
}
-(void)testMatchLastToCancel_Cancel {
    TOCCancelTokenSource* s1 = [TOCCancelTokenSource new];
    TOCCancelTokenSource* s2 = [TOCCancelTokenSource new];
    TOCCancelToken* c1 = [TOCCancelToken matchLastToCancelBetween:s1.token and:s2.token];
    TOCCancelToken* c2 = [TOCCancelToken matchLastToCancelBetween:s1.token and:s2.token];
    
    test(c1.state == TOCCancelTokenState_StillCancellable);
    test(c2.state == TOCCancelTokenState_StillCancellable);
    
    [s1 cancel];
    
    test(c1.state == TOCCancelTokenState_StillCancellable);
    test(c2.state == TOCCancelTokenState_StillCancellable);
    
    [s2 cancel];
    
    test(c1.state == TOCCancelTokenState_Cancelled);
    test(c2.state == TOCCancelTokenState_Cancelled);
}
-(void)testMatchLastToCancel_Immortal {
    TOCCancelToken* c1;
    TOCCancelToken* c2;
    @autoreleasepool {
        TOCCancelTokenSource* s1 = [TOCCancelTokenSource new];
        @autoreleasepool {
            TOCCancelTokenSource* s2 = [TOCCancelTokenSource new];
            c1 = [TOCCancelToken matchLastToCancelBetween:s1.token and:s2.token];
            c2 = [TOCCancelToken matchLastToCancelBetween:s1.token and:s2.token];
            
            test(c1.state == TOCCancelTokenState_StillCancellable);
            test(c2.state == TOCCancelTokenState_StillCancellable);
        }
        
        test(c1.state == TOCCancelTokenState_Immortal);
        test(c2.state == TOCCancelTokenState_Immortal);
    }
    
    test(c1.state == TOCCancelTokenState_Immortal);
    test(c2.state == TOCCancelTokenState_Immortal);
}

@end
