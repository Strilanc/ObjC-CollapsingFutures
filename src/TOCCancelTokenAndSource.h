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
     */
    TOCCancelTokenState_Immortal = 0, // note: immortal must be the default (0), to ensure nil acts like an immortal token when you get its state

    /*!
     * The cancel token is not cancelled, but may become cancelled (or immortal).
     *
     * @discussion All 'whenCancelledDo' handlers given to tokens in this state will be stored.
     * The callbacks will be run when the token becomes cancelled. or discarded when it becomes immortal.
     *
     * Note that the state of a token that can still be cancelled is volatile.
     * While you checked that a token was still cancellable, it may have already transitioned to being cancelled or immortal.
     */
    TOCCancelTokenState_StillCancellable = 1,

    /*!
     * The cancel token is already cancelled.
     *
     * @discussion All 'whenCancelledDo' handlers given to tokens in this state will be run inline.
     */
    TOCCancelTokenState_Cancelled = 2
};

/*!
 * The type of block passed to TOCCancelToken's whenCancelled method.
 * The block is called when the token has been cancelled.
 */
typedef void (^TOCCancelHandler)(void);

/*!
 * Notifies you when operations should be cancelled.
 * 
 * @discussion A cancel token can be in three states: cancelled, still-cancellable, and immortal.
 *
 * The nil cancel token is considered to be immortal.
 *
 * A token in the immortal state is permanently immortal and not cancelled, and will immediately discard any cancel handlers being registered to it without running them.
 *
 * A token in the cancelled state is permanently cancelled, and will immediately run+discard any cancel handlers being registered to it.
 *
 * A token in the still-cancellable state can be cancelled by its source, causing it to run+discard all registered cancel handlers and transition to the cancelled state.
 *
 * A token in the still-cancellable state can also transition to the immortal state, if its source is deallocated, causing it to discard all registered cancel handlers without running them.
 *
 * TOCCancelToken is thread safe.
 * It can be accessed from multiple threads concurrently.
 *
 * Use whenCancelledDo to add a block to be called once the token has been cancelled.
 *
 * Use isAlreadyCancelled to determine if the token has already been cancelled, and canStillBeCancelled to determine if the token is not cancelled and not immortal.
 *
 * Use the TOCCancelTokenSource class to control your own TOCCancelToken instances.
 */
@interface TOCCancelToken : NSObject

/*!
 * Returns a token that has already been cancelled.
 *
 * @result A TOCCancelToken in the cancelled state.
 */
+(TOCCancelToken *)cancelledToken;

/*!
 * Returns a token that will never be cancelled.
 *
 * @result A TOCCancelToken permanently in the uncancelled state.
 *
 * @discussion Immortal tokens do not hold onto cancel handlers.
 * Cancel handlers given to an immortal token's whenCancelledDo will not be retained, stored, or called.
 *
 * This method is guaranteed to return a non-nil result, even though a nil cancel token is supposed to be treated exactly like an immortal token.
 */
+(TOCCancelToken *)immortalToken;

/*!
 * Returns the current state of the receiving cancel token: cancelled, immortal, or still-cancellable.
 *
 * @discussion Note that the state of a token that can still be cancelled is volatile.
 * While you checked that a token was still cancellable, it may have already transitioned to being cancelled or immortal.
 */
-(enum TOCCancelTokenState) state;

/*!
 * Determines if the token is in the cancelled state, as opposed to being still-cancellable or immortal.
 */
-(bool)isAlreadyCancelled;

/*!
 * Determines if the token is in the still-cancellable state, as opposed to being cancelled or immortal.
 *
 * @discussion Note that the state of a token that can still be cancelled is volatile.
 * While you checked that canStillBeCancelled returned true, the token may have already transitioned to being cancelled or immortal.
 */
-(bool)canStillBeCancelled;

// note: do NOT include an isImmortal method. A nil cancel token is supposed to act like an immortal token, but [nil isImmortal] would return false

/*!
 * Registers a cancel handler block to be called once the receiving token is cancelled.
 *
 * @param cancelHandler The block to call once the token is cancelled.
 *
 * @discussion If the token is already cancelled, the handler is run inline.
 *
 * If the token is or becomes immortal, the handler is not kept.
 *
 * The handler will be called either inline on the calling thread or on the thread that cancels the token.
 *
 * When this method is called from the main thread, the cancel handler is guaranteed to also run on the main thread.
 */
-(void)whenCancelledDo:(TOCCancelHandler)cancelHandler;

/*!
 * Registers a cancel handler block to be called once the receiving token is cancelled.
 *
 * @param cancelHandler The block to call once the token is cancelled.
 *
 * @param unlessCancelledToken If this token is cancelled before the receiving token, the handler is discarded without being called.
 *
 * @discussion If the token is already cancelled, the handler is run inline.
 *
 * If the token is or becomes immortal, the handler is not kept.
 *
 * If the same token is used as both the receiving and unlessCancelled token, the cancel handler is discarded without being run.
 *
 * The handler will be called either inline on the calling thread or on the thread that cancels the token.
 *
 * When this method is called from the main thread, the cancel handler is guaranteed to also run on the main thread.
 */
-(void) whenCancelledDo:(TOCCancelHandler)cancelHandler
                 unless:(TOCCancelToken*)unlessCancelledToken;

@end

/*!
 * Creates and controls a TOCCancelToken.
 *
 * @discussion Use the token property to access the token controlled by a token source.
 *
 * Use the cancel or tryCancel methods to cancel the token controlled by a token source.
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
 * If the cancel token is cancelled, the resulting source is cancelled.
 *
 * @param untilCancelledToken The token whose cancellation forces the resulting cancel token source's token to be cancelled.
 * Allowed to be nil, in which case the returned cancel token source is just a normal cancel token source.
 *
 * @result A cancel token source that depends on the given cancel token.
 *
 * @discussion The returned source can still be cancelled normally.
 */
+(TOCCancelTokenSource*) cancelTokenSourceUntil:(TOCCancelToken*)untilCancelledToken;

@end
