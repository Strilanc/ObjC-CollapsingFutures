#import <Foundation/Foundation.h>
#import "TOCFuture.h"

@interface NSArray (TOCFutureArrayUtil)

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
-(TOCFuture*) finallyAll;

-(TOCFuture*) finallyAllUnless:(TOCCancelToken*)unlessCancelledToken;

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
 * For example, [@[[TOCFuture futureWithResult:@1], [TOCFuture futureWithResult:@2]] thenAll] is equivalent to [TOCFuture futureWithResult@[@1, @2]].
 */
-(TOCFuture*) thenAll;

-(TOCFuture*) thenAllUnless:(TOCCancelToken*)unlessCancelledToken;

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
-(NSArray*) orderedByCompletion;

-(NSArray*) orderedByCompletionUnless:(TOCCancelToken*)unlessCancelledToken;

@end
