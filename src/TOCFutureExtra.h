#import <Foundation/Foundation.h>
#import "TOCFutureAndSource.h"

@interface TOCFuture (TOCFutureExtra)

/*!
 * Determines if the receiving future has failed with a cancellation token as its failure value.
 */
-(bool)hasFailedWithCancel;

/*!
 * Returns a future that completes with the value returned by a function run via grand central dispatch.
 *
 * @param operation The operation to eventually evaluate.
 *
 * @param queue The gcd queue to dispatch the operation on.
 *
 * @result A future that completes once the operation has been completed, and contains the operation's result.
 */
+(TOCFuture*) futureWithResultFromOperation:(id (^)(void))operation
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
+(TOCFuture*) futureWithResultFromOperation:(id(^)(void))operation
                            invokedOnThread:(NSThread*)thread;

/*!
 * Returns a future that will contain the given result after the given delay, unless cancelled.
 *
 * @param resultValue The value the resulting future should complete with, after the delay has passed.
 *
 * @param delay The amount of time to wait, in seconds, before the resulting future completes.
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
                    afterDelay:(NSTimeInterval)delay
                        unless:(TOCCancelToken*)unlessCancelledToken;

/*!
 * Returns a future that will contain the given result after the given delay.
 *
 * @param resultValue The value the resulting future should complete with, after the delay has passed.
 *
 * @param delay The amount of time to wait, in seconds, before the resulting future completes.
 * Must not be negative or NaN (raises exception).
 * A delay of 0 results in a future that's already completed.
 * A delay of INFINITY result in an immortal future that never completes.
 *
 * @result A delayed future result.
 */
+(TOCFuture*) futureWithResult:(id)resultValue
                    afterDelay:(NSTimeInterval)delay;

@end
