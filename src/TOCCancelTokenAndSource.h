#import <Foundation/Foundation.h>

@class TOCCancelTokenSource;

@class TOCFutureSource;

/*!
 * The states that a cancel token can be in.
 *
 * @discussion A nil cancel token is considered to be in the immortal state.
 */
enum TOCCancelTokenState {
    /*!
     * The cancel token is not cancelled and will never be cancelled.
     *
     * @discussion All 'whenCancelledDo' handlers given to tokens in this state will be discarded without being run.
     *
     * A token becomes immortal when its source is deallocated without having cancelled the token.
     *
     * nil tokens are always treated as if they were a token in the immortal state.
     */
    TOCCancelTokenState_Immortal = 0, // note: immortal must be the default (0), to ensure nil acts like an immortal token when you get its state
    
    /*!
     * The cancel token is not cancelled, but may become cancelled (or immortal).
     *
     * @discussion All 'whenCancelledDo' handlers given to tokens in this state will be stored.
     * The handlers will be run when the token becomes cancelled, or discarded when it becomes immortal.
     *
     * Note that a token in this state is volatile.
     * While you checked that a token was still-cancellable, it may have concurrently been cancelled or become immortal.
     */
    TOCCancelTokenState_StillCancellable = 1,
    
    /*!
     * The cancel token has been permanently cancelled.
     *
     * @discussion All 'whenCancelledDo' handlers given to tokens in this state will be run inline.
     */
    TOCCancelTokenState_Cancelled = 2
};

/*!
 * The type of block passed to a TOCCancelToken's 'whenCancelledDo' method, to be called when the token has been cancelled.
 */
typedef void (^TOCCancelHandler)(void);

/*!
 * Notifies you when operations should be cancelled.
 *
 * @discussion TOCCancelToken is thread safe.
 * It can be accessed from multiple threads concurrently.
 *
 * Use `whenCancelledDo` on a cancel token to add a block to be called once it has been cancelled.
 *
 * Use a new instance of `TOCCancelTokenSource`to create and control your own `TOCCancelToken` instance.
 *
 * Use `isAlreadyCancelled` and `canStillBeCancelled` on a cancel token to inspect its current state.
 *
 * A cancel token can be in one of three states: cancelled, immortal, or still-cancellable.
 *
 * A token in the immortal state is permanently immortal and not cancelled.
 * Immortal tokens immediately discard (without running) all cancel handlers given to them.
 * The nil cancel token is considered to be immortal.
 *
 * A token in the cancelled state is permanently cancelled.
 * Cancelled tokens immediately run, then discard, all cancel handlers given to them.
 *
 * A token in the still-cancellable state can be cancelled by its source's `cancel` method or immortalized by its source being deallocated.
 * Still-cancellable tokens store all cancel handlers given to them, until they transition to being cancelled or immortal.
 * Still-cancellable tokens are volatile: while you inspect their state. they can be cancelled concurrently.
 */
@interface TOCCancelToken : NSObject

/*!
 * Returns a cancel token that has already been cancelled.
 *
 * @result A `TOCCancelToken` in the cancelled state.
 */
+(TOCCancelToken *)cancelledToken;

/*!
 * Returns a cancel token that will never ever be cancelled.
 *
 * @result A non-nil `TOCCancelToken` permanently in the uncancelled state.
 *
 * @discussion The result of this method is non-nil, even though a nil cancel token is supposed to be treated exactly like an immortal token.
 * Useful for cases where that equivalence is unfortunately broken (e.g. placing into an NSArray).
 */
+(TOCCancelToken *)immortalToken;

/*!
 * Returns the current state of the receiving cancel token: cancelled, immortal, or still-cancellable.
 *
 * @discussion Tokens that are cancelled or immortal are stable.
 * Tokens that are still-cancellable are volatile.
 * While you checked that a token was in the still-cancellable state, it may have been concurrently cancelled or immortalized.
 */
-(enum TOCCancelTokenState) state;

/*!
 * Determines if the receiving cancel token is in the cancelled state, as opposed to being still-cancellable or immortal.
 */
-(bool)isAlreadyCancelled;

/*!
 * Determines if the receiving cancel token is in the still-cancellable state, as opposed to being cancelled or immortal.
 *
 * @discussion Cancel tokens that can still be cancelled are volatile.
 * While you checked that `canStillBeCancelled` returned true, the receiving cancel token may have been concurrently cancelled or immortalized.
 */
-(bool)canStillBeCancelled;

// ---
// note to self:
// do NOT include an isImmortal method. A nil cancel token is supposed to act like an immortal token, but [nil isImmortal] would return false
// ---

/*!
 * Registers a cancel handler block to be called once the receiving token is cancelled.
 *
 * @param cancelHandler The block to call once the token is cancelled.
 *
 * @discussion If the token is already cancelled, the handler is run inline.
 *
 * If the token is or becomes immortal, the handler is discarded without being run.
 *
 * When registered from the main thread, the given handler is guaranteed to also run on the main thread.
 * When the receiving token is already cancelled, the given handler is run inline (before returning to the caller).
 * Otherwise the handler will run on the thread that cancels the token.
 */
-(void)whenCancelledDo:(TOCCancelHandler)cancelHandler;

/*!
 * Registers a cancel handler block to be called once the receiving token is cancelled, unless another token is cancelled before the handler runs.
 *
 * @param cancelHandler The block to call once the receiving token is cancelled.
 *
 * @param unlessCancelledToken If this argument is cancelled before the receiving token, the handler is discarded without being called.
 * If it is cancelled after the receiving token, but before the handler has run, the handler may or may not run.
 *
 * @discussion If the unlessCancelledToken was already cancelled, the handler is discarded without being run.
 *
 * If the receiving token is immortal or becomes immortal, the handler is discarded without being run.
 *
 * If the same token is used as both the receiving and unlessCancelled tokens, the handler is discarded without being run.
 *
 * When registered from the main thread, the handler is guaranteed to be run on the main thread.
 * When the receiving token is already cancelled, the handler is run inline (before returning to the caller).
 * Otherwise the handler will run on the thread that cancels the token.
 *
 * If the unlessCancelledToken token is cancelled after the receiving token, but before the handler has been run, the handler may or may not run.
 *
 * A case where the handler is guaranteed not to be run, despite the unlessCancelledToken being cancelled after the receiving token, is when
 * the handler has been automatically queued onto the main thread but not run yet.
 * If you are on the main thread, and determine that the given unlessCancelledToken has been cancelled and the handler has not run yet,
 * then it is guaranteed that the handler will not be run.
 */
-(void) whenCancelledDo:(TOCCancelHandler)cancelHandler
                 unless:(TOCCancelToken*)unlessCancelledToken;

@end

/*!
 * Creates and controls a `TOCCancelToken`.
 *
 * @discussion Use the token property to access the token controlled by a token source.
 *
 * Use the `cancel` or `tryCancel` methods to cancel the token controlled by a token source.
 *
 * When a token source is deallocated, without its token having been cancelled, its token becomes immortal.
 * Immortal tokens discard all cancel handlers without running them.
 */
@interface TOCCancelTokenSource : NSObject

/*!
 * Returns the token controlled by the receiving token source.
 */
@property (readonly, nonatomic) TOCCancelToken* token;

/*!
 * Cancels the token controlled by the receiving token source.
 *
 * @discussion If the token has already been cancelled, cancel has no effect.
 */
-(void) cancel;

/*!
 * Attempts to cancel the token controlled by the receiving token source.
 *
 * @result True if the token controlled by this source transitioned to the cancelled state, or false if the token was already cancelled.
 */
-(bool) tryCancel;

/*!
 * Creates and returns a cancel token source that is dependent on the given cancel token.
 * If the given cancel token is cancelled, the resulting cancel token source automatically cancels its own token.
 *
 * @param untilCancelledToken The token whose cancellation forces the resulting cancel token source's token to be cancelled.
 * Allowed to be nil, in which case the returned cancel token source is just a normal new cancel token source.
 *
 * @result A cancel token source that depends on the given cancel token.
 *
 * @discussion The returned cancel token source can still be cancelled normally.
 */
+(TOCCancelTokenSource*) cancelTokenSourceUntil:(TOCCancelToken*)untilCancelledToken;

@end
