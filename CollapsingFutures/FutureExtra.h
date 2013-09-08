#import <Foundation/Foundation.h>
#import "Future.h"

@interface Future (FutureExtra)

/// @abstract Returns a future that completes with the value returned by a function run via grand central dispatch.
+(Future*) futureWithResultFromOperation:(id (^)(void))operation
                       dispatchedOnQueue:(dispatch_queue_t)queue;

/// @abstract Returns a future that completes with the value returned by a function invoked on the given thread.
/// @param operation The function to run. Must not be nil.
/// @param thread The thread to invoke the function on. Must not be nil.
+(Future*) futureWithResultFromOperation:(id(^)(void))operation
                         invokedOnThread:(NSThread*)thread;

/// @abstract Returns a future that completes after a given delay (mechanism unspecified [timer, grand central dispatch, whatever]).
/// @param resultValue The result that the future will succeed with after the given delay.
/// @param delay The number of seconds the future is incomplete for.
/// Must not be negative or NaN (raises exception).
/// A delay of 0 results in a future that's already completed.
/// A delay of INFINITY results in a future that's never completed.
+(Future*) futureWithResult:(id)resultValue
                 afterDelay:(NSTimeInterval)delay;

/// @abstract Takes an array of futures and returns an array of the "same" futures, but with later-completing futures later in the array.
/// @param futures The array of futures. Must not be nil, and must contain only non-nil instances of Future.
+(NSArray*) orderedByCompletion:(NSArray*)futures;

/// @abstract Takes an array of futures and returns a future that, when they've all completed with a result, succeeds with an array of those results.
/// @param futures The array of futures. Must not be nil, and must contain only non-nil instances of Future.
/// @discussion If any of the futures fails, the returned future will fail with the array of futures once they've all completed.
/// Passing in an empty array results in an immediatelly-succeeded future containing an empty array.
+(Future*) whenAll:(NSArray*)futures;

@end
