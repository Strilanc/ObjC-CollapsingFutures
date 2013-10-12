#import <Foundation/Foundation.h>
#import "TOCFuture.h"

@interface TOCFuture (TOCFutureExtra)

/// @abstract Returns a future that completes with the value returned by a function run via grand central dispatch.
+(TOCFuture*) futureWithResultFromOperation:(id (^)(void))operation
                          dispatchedOnQueue:(dispatch_queue_t)queue;

/// @abstract Returns a future that completes with the value returned by a function invoked on the given thread.
/// @param operation The function to run. Must not be nil.
/// @param thread The thread to invoke the function on. Must not be nil.
+(TOCFuture*) futureWithResultFromOperation:(id(^)(void))operation
                            invokedOnThread:(NSThread*)thread;

/// @abstract Returns a future that completes after a given delay (mechanism unspecified [timer, grand central dispatch, whatever]).
/// @param resultValue The result that the future will succeed with after the given delay.
/// @param delay The number of seconds the future is incomplete for.
/// Must not be negative or NaN (raises exception).
/// A delay of 0 results in a future that's already completed.
/// A delay of INFINITY results in a future that's never completed.
+(TOCFuture*) futureWithResult:(id)resultValue
                    afterDelay:(NSTimeInterval)delay;

+(TOCFuture*) futureWithResult:(id)resultValue
                    afterDelay:(NSTimeInterval)delay
                        unless:(TOCCancelToken*)unlessCancelledToken;

@end
