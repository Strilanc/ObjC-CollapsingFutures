#import <Foundation/Foundation.h>

/*!
 * A block that starts an asynchronous operation whose result must be terminated when the given "until"-type cancel token is cancelled.
 *
 * @param untilCancelledToken Determines the lifetime of the operation's result.
 * The result must be cleaned up when the token is cancelled, even if the operation has completed.
 * In cases where the operation hasn't finished yet when the token is cancelled, it should clean up as soon as possible and cancel its result.
 *
 * @result A future representing the result of the eventual result of the asynchronous operation.
 * Must be cleaned up when the untilCancelledToken is cancelled.
 *
 * @discussion The result MUST be terminated and cleaned up when untilCancelledToken is cancelled, EVEN IF the operation has already finished.
 *
 * If the operation has not finished yet, cancelling the untilCancelledToken should immediately cancel it and its result.
 */
typedef TOCFuture* (^AsynchronousUntilCancelledOperationStarter)(TOCCancelToken* untilCancelledToken);
