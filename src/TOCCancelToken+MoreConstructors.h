#import "TOCCancelTokenAndSource.h"

@interface TOCCancelToken (MoreConstructors)

/*!
 * Returns a cancel token that will be cancelled when either of the given cancel tokens is cancelled.
 *
 * @param token1 A token whose cancellation forces the returned token to become cancelled.
 * If token1 does not become immortal, the returned token also can't become immortal.
 *
 * @param token2 Another token whose cancellation forces the returned token to become cancelled.
 * If token2 does not become immortal, the returned token also can't become immortal.
 *
 * @result A cancel token for the "minimum" of the two cancel tokens' lives.
 *
 * @discussion The returned cancel token is guaranteed to become immortal if both the given tokens become immortal.
 *
 * The result may be one of the given tokens, instead of a new token. Specifically:
 *
 * - If one of the given tokens has already been cancelled, it will be used as the result.
 *
 * - If one of the given tokens has already become immortal, the other will be used as the result.
 *
 * - If the given tokens are actually the same token, it is used as the result.
 */
+(TOCCancelToken*) matchFirstToCancelBetween:(TOCCancelToken*)token1
                                         and:(TOCCancelToken*)token2;

/*!
 * Returns a cancel token that will be cancelled when both of the given cancel tokens are cancelled.
 *
 * @param token1 A token that must be cancelled in order for the returned token to be cancelled.
 * If token1 becomes immortal, the returned token becomes immortal.
 *
 * @param token2 Another token that must be cancelled in order for the returned token to be cancelled.
 * If token2 becomes immortal, the returned token becomes immortal.
 *
 * @result A cancel token for the "maximum" of the two cancel tokens' lives.
 *
 * @discussion The returned cancel token is guaranteed to become immortal if either of the given tokens becomes immortal.
 *
 * The result may be one of the given tokens, instead of a new token. Specifically:
 *
 * - If one of the given tokens has already been cancelled, the other will be used as the result.
 *
 * - If one of the given tokens has already become immortal, it will be used as the result.
 *
 * - If the given tokens are actually the same token, it is used as the result.
 */
+(TOCCancelToken*) matchLastToCancelBetween:(TOCCancelToken*)token1
                                        and:(TOCCancelToken*)token2;

@end
