#import <Foundation/Foundation.h>

/// @abstract A TOCFuture is a result that may fail and may not be ready yet.
///
/// @discussion
/// Use the then/catch/finally methods to eventually access a future's result or failure.
///
/// If a future has already completed, you can use the forceGet methods to access its result or failure right away.
///
/// TOCFuture is thread-safe.
///
/// TOCFuture is a collapsing type: you never see a future containing a future result.
/// A future that would have had a future result will instead match that future result's failure or result.
///
/// Use the TOCFutureSource class to create and set your own futures.
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
-(TOCFuture *)then:(id(^)(id value))resultContinuation;

/// @abstract Registers a continuation to run when this future fails, exposing the eventual result as a future.
/// @result A future for the eventual result of running the continuation on this future's failure value.
/// If this future completes with a result, the continuation is not run and the returned future gets the same result.
/// @discussion If this future has already failed the continuation is run inline.
/// When this future fails, the continuation will be run inline.
/// If this future completes with a result, the continuation is not run and the returned future gets the same result.
/// If the continuation returns a future, automatic collapse is triggered and the returned future will match it instead of having it as a result.
-(TOCFuture *)catch:(id(^)(id error))failureContinuation;

/// @abstract Registers a continuation to run when this future fails or completes with a result, exposing the eventual result as a future.
/// @result A future for the eventual result of running the continuation after this future has completed or failed.
/// @discussion If this future has already completed or failed, the continuation is run inline.
/// When this future completes or fails, the continuation will be run inline.
/// If the continuation returns a future, automatic collapse is triggered and the returned future will match it instead of having it as a result.
-(TOCFuture *)finally:(id(^)(TOCFuture * completed))completionContinuation;

/// @abstract Registers a handler to run when this future completes with a result.
/// @discussion If this future has already completed, the handler is run inline.
/// When this future completes, the handler will be run inline.
/// If this future fails then the handler is not run.
-(void) thenDo:(void(^)(id result))resultHandler;

/// @abstract Registers a handler to run when this future fails.
/// @discussion If this future has already failed, the handler is run inline.
/// When this future fails, the handler will be run inline.
/// If this future does not fail then the handler is not run.
-(void) catchDo:(void(^)(id error))failureHandler;

/// @abstract Registers a handler to run when this future completes or fails.
/// @discussion If this future has already completed or failed, the handler is run inline.
/// When this future completes or fails, the handler will be run inline.
-(void) finallyDo:(void(^)(TOCFuture * completed))completionHandler;

@end

/// @abstract The type of block passed to future 'finallyDo'.
typedef void (^TOCFutureCompletionHandler)(TOCFuture * completed);
/// @abstract The type of block passed to future 'thenDo'.
typedef void (^TOCFutureResultHandler)(id value);
/// @abstract The type of block passed to future 'catchDo'.
typedef void (^TOCFutureFailureHandler)(id failure);

/// @abstract The type of block passed to future 'finally'.
typedef id (^TOCFutureCompletionContinuation)(TOCFuture * completed);
/// @abstract The type of block passed to future 'then'.
typedef id (^TOCFutureResultContinuation)(id value);
/// @abstract The type of block passed to future 'catch'.
typedef id (^TOCFutureFailureContinuation)(id failure);

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
