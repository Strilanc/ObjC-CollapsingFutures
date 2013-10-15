#import "TOCFuture.h"
#import "TOCCommonDefs.h"

@implementation TOCFuture {
@private id value;
@private bool ifDoneHasSucceeded;
@private bool hasBeenSet;
@private TOCCancelTokenSource* completionSource;
@private TOCCancelToken* completionToken;
}

+(TOCFuture *)futureWithResult:(id)resultValue {
    if ([resultValue isKindOfClass:[TOCFuture class]]) {
        return resultValue;
    }
    
    TOCFuture *future = [TOCFuture new];
    future->completionToken = [TOCCancelToken cancelledToken];
    future->ifDoneHasSucceeded = true;
    future->value = resultValue;
    return future;
}
+(TOCFuture *)futureWithFailure:(id)failureValue {
    TOCFuture *future = [TOCFuture new];
    future->completionToken = [TOCCancelToken cancelledToken];
    future->ifDoneHasSucceeded = false;
    future->value = failureValue;
    return future;
}

+(TOCFuture*) __ForSource__completableFuture {
    TOCFuture* future = [TOCFuture new];
    future->completionSource = [TOCCancelTokenSource new];
    future->completionToken = future->completionSource.token;
    return future;
}
-(bool) __ForSource__trySetResult:(id)finalResult {
    // automatic flattening
    if ([finalResult isKindOfClass:[TOCFuture class]]) {
        return [self __trySetWithUnwrap:finalResult];
    }

    return [self __trySet:finalResult
                succeeded:true
               isUnwiring:false];
}
-(bool) __ForSource__trySetFailure:(id)finalFailure {
    return [self __trySet:finalFailure
                succeeded:false
               isUnwiring:false];
}
-(void) __ForSource__trySetEternal {
    @synchronized(self) {
        if (!hasBeenSet) {
            completionSource = nil;
            hasBeenSet = true;
        }
    }
}

-(bool) __trySet:(id)finalValue
       succeeded:(bool)succeeded
      isUnwiring:(bool)unwiring {
    @synchronized(self) {
        if (hasBeenSet && !unwiring) return false;
        hasBeenSet = true;
        value = finalValue;
        ifDoneHasSucceeded = succeeded;
    }
    [completionSource cancel];
    return true;
}
-(bool) __trySetWithUnwrap:(TOCFuture*)futureFinalResult {
    require(futureFinalResult != nil);
    
    @synchronized(self) {
        if (hasBeenSet) return false;
        hasBeenSet = true;
    }
    
    [futureFinalResult finallyDo:^(TOCFuture *completed) {
        [self __trySet:completed->value
             succeeded:completed->ifDoneHasSucceeded
            isUnwiring:true];
    } unless:nil];
    
    return true;
}


-(TOCCancelToken*) cancelledOnCompletionToken {
    return completionToken;
}

-(bool)isIncomplete {
    return ![completionToken isAlreadyCancelled];
}
-(bool)hasResult {
    return [completionToken isAlreadyCancelled] && ifDoneHasSucceeded;
}
-(bool)hasFailed {
    return [completionToken isAlreadyCancelled] && !ifDoneHasSucceeded;
}
-(id)forceGetResult {
    require([self hasResult]);
    return value;
}
-(id)forceGetFailure {
    require([self hasFailed]);
    return value;
}

-(void)finallyDo:(TOCFutureFinallyHandler)completionHandler
          unless:(TOCCancelToken *)unlessCancelledToken {
    require(completionHandler != nil);
    
    __weak TOCFuture* weakSelf = self;
    [completionToken whenCancelledDo:^{ completionHandler(weakSelf); }
                                     unless:unlessCancelledToken];
}

-(void)thenDo:(TOCFutureThenHandler)resultHandler
       unless:(TOCCancelToken *)unlessCancelledToken {
    require(resultHandler != nil);
    
    [self finallyDo:^(TOCFuture *completed) {
        if (completed->ifDoneHasSucceeded) {
            resultHandler(completed->value);
        }
    } unless:unlessCancelledToken];
}

-(void)catchDo:(TOCFutureCatchHandler)failureHandler
        unless:(TOCCancelToken *)unlessCancelledToken {
    require(failureHandler != nil);
    
    [self finallyDo:^(TOCFuture *completed) {
        if (!completed->ifDoneHasSucceeded) {
            failureHandler(completed->value);
        }
    } unless:unlessCancelledToken];
}

-(TOCFuture *)finally:(TOCFutureFinallyContinuation)completionContinuation
               unless:(TOCCancelToken *)unlessCancelledToken {
    require(completionContinuation != nil);
    
    TOCFutureSource* resultSource = [TOCFutureSource new];
    
    [self finallyDo:^(TOCFuture *completed) {
        [resultSource trySetResult:completionContinuation(completed)];
    } unless:unlessCancelledToken];
    [unlessCancelledToken whenCancelledDo:^{
        [resultSource trySetFailure:unlessCancelledToken];
    } unless:completionToken];
    
    return resultSource.future;
}

-(TOCFuture *)then:(TOCFutureThenContinuation)resultContinuation unless:(TOCCancelToken *)unlessCancelledToken {
    require(resultContinuation != nil);
    
    return [self finally:^id(TOCFuture *completed) {
        if (completed->ifDoneHasSucceeded) {
            return resultContinuation(completed->value);
        } else {
            return completed;;
        }
    } unless:unlessCancelledToken];
}

-(TOCFuture *)catch:(TOCFutureCatchContinuation)failureContinuation
             unless:(TOCCancelToken *)unlessCancelledToken {
    require(failureContinuation != nil);
    
    return [self finally:^(TOCFuture *completed) {
        if (completed->ifDoneHasSucceeded) {
            return completed->value;
        } else {
            return failureContinuation(completed->value);
        }
    } unless:unlessCancelledToken];
}

-(NSString*) description {
    @synchronized(self) {
        bool isIncomplete = [completionToken isAlreadyCancelled];
        bool isStuck = ![completionToken canStillBeCancelled];
        
        if (isIncomplete) {
            if (isStuck) return @"Incomplete Future [Eternal]";
            if (hasBeenSet) return @"Incomplete Future [Set]";
            return @"Incomplete Future";
        }
        return [NSString stringWithFormat:@"Future with %@: %@",
                ifDoneHasSucceeded ? @"Result" : @"Failure",
                value];
    }
}

@end

@implementation TOCFutureSource

@synthesize future;

-(TOCFutureSource*) init {
    self = [super init];
    if (self) {
        self->future = [TOCFuture __ForSource__completableFuture];
    }
    return self;
}

-(void) dealloc {
    [future __ForSource__trySetEternal];
}
-(bool) trySetResult:(id)finalResult {
    return [future __ForSource__trySetResult:finalResult];
}
-(bool) trySetFailure:(id)finalFailure {
    return [future __ForSource__trySetFailure:finalFailure];
}

-(void) forceSetResult:(id)finalResult {
    require([self trySetResult:finalResult]);
}
-(void) forceSetFailure:(id)finalFailure {
    require([self trySetFailure:finalFailure]);
}

-(NSString*) description {
    return [NSString stringWithFormat:@"Future Source: %@", future];
}

@end
