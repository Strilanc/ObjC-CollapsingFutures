#import <Foundation/Foundation.h>

/*!
 * The type of block passed to TOCCancelToken's whenCancelled method.
 * The block is called when the token has been cancelled.
 */
typedef void (^TOCCancelHandler)(void);

/*!
 * Notifies you when operations should be cancelled.
 * 
 * @discussion TOCCancelToken is thread safe.
 * It can be accessed from multiple threads concurrently.
 *
 * Use whenCancelledDo to add a block to be called once the token has been cancelled.
 *
 * Use isAlreadyCancelled to determine it the token has already been cancelled.
 *
 * Use the TOCCancelTokenSource class to control your own TOCCancelToken instances.
 */
@interface TOCCancelToken : NSObject

+(TOCCancelToken *)cancelledToken;
+(TOCCancelToken *)immortalToken;

-(bool)isAlreadyCancelled;

-(void)whenCancelledDo:(TOCCancelHandler)cancelHandler;

-(void) whenCancelledDo:(TOCCancelHandler)cancelHandler
        unlessCancelled:(TOCCancelToken*)unlessCancelledToken;

@end

@interface TOCCancelTokenSource : NSObject

@property (readonly, nonatomic) TOCCancelToken* token;

-(void) cancel;

-(bool) tryCancel;

@end
