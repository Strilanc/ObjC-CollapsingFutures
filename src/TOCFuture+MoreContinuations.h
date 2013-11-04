#import <Foundation/Foundation.h>
#import "TOCFutureAndSource.h"

/*!
 * Utility methods involving continuing off of futures (then/catch/finally).
 */
@interface TOCFuture (MoreContinuations)

/*!
 * Eventually evaluates a 'then' continuation on the receiving future's result, or else propagates the receiving future's failure.
 *
 * @result A future for the eventual result of evaluating the given 'then' block on the receiving future's result, or else a failure if the receiving future fails.
 *
 * @param resultContinuation The block to evaluate when the future succeeds with a result.
 *
 * @discussion If the receiving future has already succeeded with a result, the continuation is run inline.
 *
 * If the receiving future fails, instead of succeeding with a result, the continuation is not run and the failure is propagated into the returned future.
 *
 * If the continuation returns a future, instead of a normal value, then this method's result is automatically flattened to match that future instead of containing it.
 */
-(TOCFuture *)then:(TOCFutureThenContinuation)resultContinuation;

/*!
 * Eventually matches the receiving future's result, or else evaluates a 'catch' continuation on the receiving future's failure.
 *
 * @param failureContinuation The block to evaluate when the future fails.
 *
 * @result A future for the eventual result of the receiving future, or else the eventual result of running the receiving future's failure through the given 'catch' block.
 *
 * @discussion If the receiving future has already failed, the continuation is run inline.
 *
 * If the continuation returns a future, instead of a normal value, then this method's result is automatically flattened to match that future instead of containing it.
 */
-(TOCFuture *)catch:(TOCFutureCatchContinuation)failureContinuation;

/*!
 * Eventually evaluates a 'finally' continuation on the receiving future, once it has completed with a result or failed.
 *
 * @param completionContinuation The block to evaluate when the future fails or completes with a result.
 *
 * @result A future for the eventual result of evaluating the given 'finally' block on the receiving future once it has completed.
 *
 * @discussion If the receiving future has already completed, the continuation is run inline.
 *
 * If the continuation returns a future, instead of a normal value, then this method's result is automatically flattened to match that future instead of containing it.
 */
-(TOCFuture *)finally:(TOCFutureFinallyContinuation)completionContinuation;

/*!
 * Eventually runs a 'then' handler on the receiving future's result.
 *
 * @param resultHandler The block to run when the future succeeds with a result.
 *
 * @discussion If the receiving future has already succeeded with a result, the handler is run inline.
 *
 * If the receiving future fails, instead of succeeding with a result, the handler is not run.
 */
-(void) thenDo:(TOCFutureThenHandler)resultHandler;

/*!
 * Eventually runs a 'catch' handler on the receiving future's failure.
 *
 * @param failureHandler The block to run when the future fails.
 *
 * @discussion If the receiving future has already failed, the handler is run inline.
 *
 * If the receiving future succeeds with a result, instead of failing, the handler is not run.
 */
-(void) catchDo:(TOCFutureCatchHandler)failureHandler;

/*!
 * Eventually runs a 'finally' handler on the receiving future, once it has completed with a result or failed.
 *
 * @param completionHandler The block to run when the future fails or completes with a result.
 *
 * @discussion If the receiving future has already completed with a result or failed, the handler is run inline.
 */
-(void) finallyDo:(TOCFutureFinallyHandler)completionHandler;

/*!
 * Returns a future that will match the receiving future, except it immediately cancels if the given cancellation tokens is cancelled first.
 *
 * @param unlessCancelledToken The cancellation token that can be used to cause the resulting future to immediately fail with the cancellation token as its failure value.
 * A nil cancellation token corresponds to an immortal cancellation token.
 *
 * @result A future that will either contain the same result/failure as the receiving future, or else the given cancellation token when it is cancelled.
 *
 * @discussion If the receiving future is already completed and the given cancellation token is already cancelled, the cancellation "wins".
 * The resulting future will fail with the cancellation token as its failure value.
 *
 * When the cancellation token is immortal, the receiving future may be returned unmodified and unwrapped.
 *
 * Works by registering a continuation on the receiving future.
 * If the cancellation token is cancelled, this continuation is immediately cleaned up.
 */
-(TOCFuture*) unless:(TOCCancelToken*)unlessCancelledToken;

@end
