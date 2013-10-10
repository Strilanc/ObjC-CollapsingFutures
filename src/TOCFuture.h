#import <Foundation/Foundation.h>

@class TOCFuture;

/// @abstract The type of block passed to future 'finallyDo'.
typedef void (^TOCFutureFinallyHandler)(TOCFuture * completed);
/// @abstract The type of block passed to future 'thenDo'.
typedef void (^TOCFutureThenHandler)(id value);
/// @abstract The type of block passed to future 'catchDo'.
typedef void (^TOCFutureCatchHandler)(id failure);

/// @abstract The type of block passed to future 'finally'.
typedef id (^TOCFutureFinallyContinuation)(TOCFuture * completed);
/// @abstract The type of block passed to future 'then'.
typedef id (^TOCFutureThenContinuation)(id value);
/// @abstract The type of block passed to future 'catch'.
typedef id (^TOCFutureCatchContinuation)(id failure);

/// @abstract A TOCFuture is an eventual value. It will eventuall contain a result or a failure.
///
/// @discussion
/// TOCFuture is thread-safe. It can be accessed from multiple threads concurrently.
///
/// Use the then/catch/finally methods to continue with a block once a TOCFuture has a value.
/// You get a future for the continuation's completion when using then/catch/finally, allowing you to chain computations together.
/// The continuation block is called either on the thread registering the continuation or on the thread computing the future's result.
///
/// You can use isIncomplete/hasResult/hasFailed to determine if the future has already completed or not.
/// You can use forceGetResult/forceGetFailure to attempt to directly retrieve the future's result or failure.
/// If the future has not yet completed, using forceGetX will raise an exception.
///
/// TOCFuture is auto-collapsing/flattening: you will never see a TOCFuture with a result of type TOCFuture because it gets flattened.
/// For example, [TOCFuture futureWithResult:[TocFuture futureWithResult:@1]] is equivalent to [TocFuture futureWithResult:@1].
/// Note that automatic flattening does not apply to failures. A TOCFuture's failure may be a TOCFuture.
///
/// Use the TOCFutureSource class to control your own TOCFuture instances.
@interface TOCFuture : NSObject

/// @abstract Creates and returns a future that has already completed with the given result value.
/// @param resultValue The result the future should end up with.
/// Nil is a valid result value.
/// TOCFutures are valid result values, but trigger automatic collapsing.
/// @discussion Using a future result value causes the argument to be returned, instead of a new future.
+(TOCFuture *)futureWithResult:(id)resultValue;

/// @abstract Creates and returns a future that has already failed with the given failure value.
/// @param failureValue The failure the future should end up with.
/// Nil is a valid failure value.
/// TOCFutures are valid failure values, but are NOT UNWRAPPED like they are when used as results.
+(TOCFuture *)futureWithFailure:(id)failureValue;

/// @abstract Determines if this future has not yet completed or failed.
-(bool)isIncomplete;

/// @abstract Determines if this future has completed with a result, as opposed to having failed or still being incomplete.
-(bool)hasResult;

/// @abstract Determines if this future has failed, as opposed to having completed with a result or still being incomplete.
-(bool)hasFailed;

/// @abstract Accesses this future's result, if it has one. Otherwise raises an exception.
-(id)forceGetResult;

/// @abstract Accesses this future's failure, if it has one. Otherwise raises an exception.
-(id)forceGetFailure;

/// @abstract Registers a continuation to run when this future completes with a result, exposing the eventual result as a future.
/// @result A future for the eventual result of running the continuation on this future's result.
/// If this future fails then the continuation is not run, and the failure is propagated to the returned future.
/// @discussion If this future has already completed the continuation is run inline.
/// When this future completes, the continuation will be run inline.
/// If this future fails then the continuation is not run, and the failure is propagated to the returned future.
/// If the continuation returns a future, automatic collapse is triggered and the returned future will match it instead of having it as a result.
-(TOCFuture *)then:(TOCFutureThenContinuation)resultContinuation;

/// @abstract Registers a continuation to run when this future fails, exposing the eventual result as a future.
/// @result A future for the eventual result of running the continuation on this future's failure value.
/// If this future completes with a result, the continuation is not run and the returned future gets the same result.
/// @discussion If this future has already failed the continuation is run inline.
/// When this future fails, the continuation will be run inline.
/// If this future completes with a result, the continuation is not run and the returned future gets the same result.
/// If the continuation returns a future, automatic collapse is triggered and the returned future will match it instead of having it as a result.
-(TOCFuture *)catch:(TOCFutureCatchContinuation)failureContinuation;

/// @abstract Registers a continuation to run when this future fails or completes with a result, exposing the eventual result as a future.
/// @result A future for the eventual result of running the continuation after this future has completed or failed.
/// @discussion If this future has already completed or failed, the continuation is run inline.
/// When this future completes or fails, the continuation will be run inline.
/// If the continuation returns a future, automatic collapse is triggered and the returned future will match it instead of having it as a result.
-(TOCFuture *)finally:(TOCFutureFinallyContinuation)completionContinuation;

/// @abstract Registers a handler to run when this future completes with a result.
/// @discussion If this future has already completed, the handler is run inline.
/// When this future completes, the handler will be run inline.
/// If this future fails then the handler is not run.
-(void) thenDo:(TOCFutureThenHandler)resultHandler;

/// @abstract Registers a handler to run when this future fails.
/// @discussion If this future has already failed, the handler is run inline.
/// When this future fails, the handler will be run inline.
/// If this future does not fail then the handler is not run.
-(void) catchDo:(TOCFutureCatchHandler)failureHandler;

/// @abstract Registers a handler to run when this future completes or fails.
/// @discussion If this future has already completed or failed, the handler is run inline.
/// When this future completes or fails, the handler will be run inline.
-(void) finallyDo:(TOCFutureFinallyHandler)completionHandler;

@end

/// @abstract A TOCFutureSource is a future that can be manually given a result or failure.
///
/// @discussion
/// TOCFutureSource is thread-safe.
/// Use trySetResult and trySetFailure to cause the source's future to complete.
/// Giving a future to trySetResult triggers automatic collapse: the source's future to become 'the same', matching the given future's result or failure.
/// Giving a future to trySetFailure does not trigger automatic collapse.
@interface TOCFutureSource : TOCFuture

/// @abstract Attempts to set the source's future to complete with the given result value, unwrapping the value if it's a future.
///
/// @result Returns true when the source's future has been successfully set, and false when it was already set.
///
/// @param finalResult The result value to use.
/// TOCFutures are valid result values, but are automatically unwrapped.
/// Nil is a valid result value.
///
/// @discussion
/// No effect when the source's future was already set.
///
/// Automatically collapses nested futures. If the result value is a future F then:
/// - While F is incomplete, the source's future is incomplete (but still set).
/// - If/When F has completed with result X, the source's future has also completed with result X.
/// - If/When F has failed with failure X, the source's future has also failed with failure X.
-(bool) trySetResult:(id)finalResult;

/// @abstract Attempts to set the source's future to fail with the given failure value.
///
/// @result Returns true when the source's future has been successfully set, and false when it was already set.
///
/// @param finalFailure The failure value to use.
/// Nil is a valid failure value.
/// TOCFutures are valid failure values, but are NOT UNWRAPPED like they are when used as results.
///
/// @discussion
/// No effect when the source's future was already set.
-(bool) trySetFailure:(id)finalFailure;

@end
