#import <Foundation/Foundation.h>
#import "TOCFutureAndSource.h"
#import "TOCTypeDefs.h"
#import "TOCTimeout.h"

@interface TOCFuture (MoreConstructors)

/*!
 * Returns a future that has already failed with a timeout failure.
 *
 * A timeout failure is just an instance of TOCTimeout.
 */
+(TOCFuture*) futureWithTimeoutFailure;

/*!
 * Returns a future that has already failed with a cancellation failure.
 *
 * A cancellation failure is just an instance of TOCCancelToken.
 */
+(TOCFuture*) futureWithCancelFailure;

/*!
 * Returns a future that completes with the value returned by a function run via grand central dispatch.
 *
 * @param operation The operation to eventually evaluate.
 *
 * @param queue The gcd queue to dispatch the operation on.
 *
 * @result A future that completes once the operation has been completed, and contains the operation's result.
 */
+(TOCFuture*) futureFromOperation:(id (^)(void))operation
                dispatchedOnQueue:(dispatch_queue_t)queue;

/*!
 * Returns a future that completes with the value returned by a function run on a specified thread.
 *
 * @param operation The operation to eventually evaluate.
 *
 * @param thread The thread to perform the operation on.
 *
 * @result A future that completes once the operation has been completed, and contains the operation's result.
 */
+(TOCFuture*) futureFromOperation:(id(^)(void))operation
                  invokedOnThread:(NSThread*)thread;

/*!
 * Returns a future that will contain the given result after the given delay, unless cancelled.
 *
 * @param resultValue The value the resulting future should complete with, after the delay has passed.
 *
 * @param delayInSeconds The amount of time to wait, in seconds, before the resulting future completes.
 * Must not be negative or NaN (raises exception).
 * A delay of 0 results in a future that's already completed.
 * A delay of INFINITY result in an immortal future that never completes.
 *
 * @param unlessCancelledToken If this token is cancelled before the delay expires, the future immediately fails with the cancel token as its failure.
 * Any resources being used for the delay, such as NSTimers, will also be immediately cleaned up upon cancellation.
 *
 * @result A delayed future result, unless the delay is cancelled.
 */
+(TOCFuture*) futureWithResult:(id)resultValue
                    afterDelay:(NSTimeInterval)delayInSeconds
                        unless:(TOCCancelToken*)unlessCancelledToken;

/*!
 * Returns a future that will contain the given result after the given delay.
 *
 * @param resultValue The value the resulting future should complete with, after the delay has passed.
 *
 * @param delayInSeconds The amount of time to wait, in seconds, before the resulting future completes.
 * Must not be negative or NaN (raises exception).
 * A delay of 0 results in a future that's already completed.
 * A delay of INFINITY result in an immortal future that never completes.
 *
 * @result A delayed future result.
 */
+(TOCFuture*) futureWithResult:(id)resultValue
                    afterDelay:(NSTimeInterval)delayInSeconds;

/*!
 * Returns a future that eventually contains the result, which lasts until the given token is cancelled, of an asynchronous operation as long as it completes before the given timeout.
 *
 * @param asyncOperationWithResultLastingUntilCancelled The asynchronous operation to evaluate.
 *
 * @param timeoutPeriodInSeconds The amount of time, in seconds, the asynchronous operation is given to finish before it is cancelled.
 * Must not be negative or NaN (raises exception).
 * A delay of 0 results in an immediate timeout failure without the operation even being run.
 * A delay of INFINITY results in the operation being run without a timeout.
 *
 * @param untilCancelledToken The operation, and its results, are cancelled when this token is cancelled.
 *
 * @result The eventual result of the asynchronous operation, unless the operation is cancelled or times out.
 *
 * @discussion If the operation has not yet completed when the untilCancelledToken is cancelled, the operation is immediately cancelled.
 *
 * If the operation has already completed when the untilCancelledToken is cancelled, its result is terminated / cleaned-up / dead.
 */
+(TOCFuture*) futureFromUntilOperation:(TOCUntilOperation)asyncOperationWithResultLastingUntilCancelled
                  withOperationTimeout:(NSTimeInterval)timeoutPeriodInSeconds
                                 until:(TOCCancelToken*)untilCancelledToken;

/*!
 * Returns a future for the eventual result of an asynchronous operation, unless the operation times out or is cancelled.
 *
 * @param asyncCancellableOperation The cancellable asynchronous operation to evaluate.
 *
 * @param timeoutPeriodInSeconds The amount of time, in seconds, the asynchronous operation is given to finish before it is cancelled due to a timeout.
 * Must not be negative or NaN (raises exception).
 * A delay of 0 results in an immediate timeout failure without the operation even being run.
 * A delay of INFINITY results in the operation being run without a timeout.
 *
 * @param unlessCancelledToken Cancelling this token will cancel the asynchronous operation, unless it has already finished.
 *
 * @result The eventual result of the asynchronous operation, or else a timeout or cancellation failure.
 *
 * @discussion If the operation times out, the resulting future fails with an instance of TOCTimeout as its failure.
 *
 * If the operation is cancelled, the resulting future fails with a cancel.
 *
 * If the operation finishes without being cancelled, the resulting future will match it.
 *
 * This method is unable to forward its result before the given asynchronous operation confirms it was cancelled (by cancelling the future it returned).
 * Otherwise it would be possible to leak a result that needed to be cleaned up, due to the operation's completion racing with timing out.
 */
+(TOCFuture*) futureFromUnlessOperation:(TOCUnlessOperation)asyncCancellableOperation
                            withTimeout:(NSTimeInterval)timeoutPeriodInSeconds
                                 unless:(TOCCancelToken*)unlessCancelledToken;

/*!
 * Returns a future for the eventual result of an asynchronous operation, unless the operation times out.
 *
 * @param asyncCancellableOperation The cancellable asynchronous operation to evaluate.
 *
 * @param timeoutPeriodInSeconds The amount of time, in seconds, the asynchronous operation is given to finish before it is cancelled due to a timeout.
 * Must not be negative or NaN (raises exception).
 * A delay of 0 results in an immediate timeout failure without the operation even being run.
 * A delay of INFINITY results in the operation being run without a timeout.
 *
 * @result The eventual result of the asynchronous operation, or else a timeout failure.
 *
 * @discussion If the operation times out, the resulting future fails with an instance of TOCTimeout as its failure.
 *
 * If the operation finishes without timing out or acknowledging the timeout, the resulting future will match it.
 *
 * This method is unable to forward its result before the given asynchronous operation confirms it was cancelled due to the timeout (by cancelling the future it returned).
 * Otherwise it would be possible to leak a result that needed to be cleaned up, due to the operation's completion racing with timing out.
 */
+(TOCFuture*) futureFromUnlessOperation:(TOCUnlessOperation)asyncCancellableOperation
                            withTimeout:(NSTimeInterval)timeoutPeriodInSeconds;

@end
