#import <Foundation/Foundation.h>
#import "TOCFutureAndSource.h"
#import "TOCTypeDefs.h"

@interface NSArray (TOCFuture)

/*!
 * Returns a future that succeeds with all of the futures in the receiving array, once they have all completed or failed, unless cancelled.
 *
 * @pre All items in the receiving array must be instances of TOCFuture.
 *
 * @result A future whose result will be an array containing all of the given futures.
 * If the given cancel token is cancelled before all futures in the array complete, the result fails with a cancellation.
 * @see hasFailedWithCancel
 *
 * @discussion Can be thought of as wrapping an Array-of-Futures into a Future-of-Array-of-Completed-Futures.
 *
 * A nil cancel token is treated like a cancel token that can never be cancelled.
 */
-(TOCFuture*) toc_finallyAllUnless:(TOCCancelToken*)unlessCancelledToken;

/*!
 * Returns a future that succeeds with all of the futures in the receiving array, once they have all completed or failed.
 *
 * @pre All items in the receiving array must be instances of TOCFuture.
 *
 * @result A future whose result will be an array containing all of the given futures.
 *
 * @discussion Can be thought of as wrapping an Array-of-Futures into a Future-of-Array-of-Completed-Futures.
 *
 * The future returned by this method always succeeds with a result. It is guaranteed to not contain a failure.
 */
-(TOCFuture*) toc_finallyAll;

/*!
 * Eventually gets all of the results from the futures in the receiving array, unless cancelled.
 *
 * @pre All items in the receiving array must be instances of TOCFuture.
 *
 * @result A future whose result will be an array containing all the results of the given futures,
 * unless any of the given futures fail in which case the returned future will fail with an array containing all of the given futures.
 * If the given cancel token is cancelled before all futures in the array complete, the result fails with a cancellation.
 * @see hasFailedWithCancel
 *
 * @discussion Can be thought of as flipping an Array-of-Futures into a Future-of-Array in the 'obvious' way.
 *
 * For example, @[[TOCFuture futureWithResult:@1], [TOCFuture futureWithResult:@2]].toc_thenAll is equivalent to [TOCFuture futureWithResult@[@1, @2]].
 *
 * A nil cancel token is treated like a cancel token that can never be cancelled.
 */
-(TOCFuture*) toc_thenAllUnless:(TOCCancelToken*)unlessCancelledToken;

/*!
 * Eventually gets all of the results from the futures in the receiving array.
 *
 * @pre All items in the receiving array must be instances of TOCFuture.
 *
 * @result A future whose result will be an array containing all the results of the given futures,
 * unless any of the given futures fail in which case the returned future will fail with an array containing all of the given futures.
 *
 * @discussion Can be thought of as flipping an Array-of-Futures into a Future-of-Array in the 'obvious' way.
 *
 * For example, @[[TOCFuture futureWithResult:@1], [TOCFuture futureWithResult:@2]].toc_thenAll is equivalent to [TOCFuture futureWithResult@[@1, @2]].
 */
-(TOCFuture*) toc_thenAll;

/*!
 * Immediately returns an array containing futures matching those in the receiving array, but with futures that will complete later placed later in the array, unless cancelled.
 *
 * @pre All items in the receiving array must be instances of TOCFuture.
 *
 * @result An array of futures where earlier futures complete first and each future in the returned array is matched with one from the receiving array.
 * If the given cancel token is cancelled before all futures in the array complete, the result fails with fails with a cancellation.
 * @see hasFailedWithCancel
 *
 * @discussion When one of the given futures completes, its result or failure is immediately placed into the first incomplete future in the returned array.
 *
 * The order that futures completed in in the past is not remembered.
 * Futures that had already completed will end up in the same order in the returned array as they were in the receiving array.
 *
 * A nil cancel token is treated like a cancel token that can never be cancelled.
 */
-(NSArray*) toc_orderedByCompletionUnless:(TOCCancelToken*)unlessCancelledToken;

/*!
 * Immediately returns an array containing futures matching those in the receiving array, but with futures that will complete later placed later in the array.
 *
 * @pre All items in the receiving array must be instances of TOCFuture.
 *
 * @result An array of futures where earlier futures complete first and each future in the returned array is matched with one from the receiving array.
 *
 * @discussion When one of the given futures completes, its result or failure is immediately placed into the first incomplete future in the returned array.
 *
 * The order that futures completed in in the past is not remembered.
 * Futures that had already completed will end up in the same order in the returned array as they were in the receiving array.
 */
-(NSArray*) toc_orderedByCompletion;

/*!
 * Runs all the TOCUntilOperation blocks in the array, racing the asynchronous operations they start against each other, and returns the winner as a future.
 * IMPORTANT: An operation's result MUST be cleaned up if the cancel token given to the starter is cancelled EVEN IF the operation has already completed.
 *
 * @param untilCancelledToken When this token is cancelled, both the race AND THE WINNING RESULT are cancelled, terminated, cleaned up, and generally DEAD.
 *
 * @result A future that will contain the result of the first asynchronous operation to complete, or else fail with the failures of every operation.
 * If the untilCancelledToken is cancelled before the race is over, the resulting future fails with a cancellation.
 *
 * @pre All items in the array must be TOCUntilOperation blocks.
 *
 * @discussion An TOCUntilOperation block takes an untilCancelledToken and returns a TOCFuture*.
 * The block is expected to start an asynchronous operation whose result is terminated when the token is cancelled, even if the operation has already completed.
 *
 * The untilCancelledTokens given to each racing operation are dependent, but distinct, from the untilCancelledToken given to this method.
 *
 * When a racing operation has won, all the other operations are cancelled by cancelling the untilCancelledToken that was given to them.
 *
 * You are allowed to give a nil untilCancelledToken to this method.
 * However, the individual operations will still be given a non-nil untilCancelledToken so that their results can be cleaned up in cases where multiple complete at the same time.
 * 
 * CAUTION: When writing the racing operations within the scope of the token being passed to this method, it is easy to accidentally use the wrong untilCancelledToken.
 * Double-check that the racing operation is depending on the token given to it by this method, and not the token you're giving to this method.
 *
 * @see TOCUntilOperation
 */
-(TOCFuture*) toc_raceForWinnerLastingUntil:(TOCCancelToken*)untilCancelledToken;

@end
