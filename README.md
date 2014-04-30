Collapsing Futures
==================

This is a library implementing [futures](https://en.wikipedia.org/wiki/Future_%28programming%29) in Objective-C, featuring:

- **Types**: `TOCFuture` to represent eventual results, `TOCCancelToken` to propagate cancellation notifications, `TOCFutureSource` to produce and control an eventual result, and `TOCCancelTokenSource` to produce and control a cancel token.
- **Automatic Collapsing**: You never have to worry about forgetting to unwrap or flatten a doubly-eventual future. A `[TOCFuture futureWithResult:[TOCFuture futureWithResult:@1]]` is automatically a `[TOCFuture futureWithResult:@1]`.
- **Sticky Main Thread**: Callbacks registered from the main thread will get back on the main thread before executing.  Makes UI work much easier.
- **Cancellable Operations**: All asynchronous operations have variants that can be cancelled by cancelling the `TOCCancelToken` passed to the operation's `until:` or `unless:` parameter.
- **Immortality Detection**: It is impossible to create new space leaks by consuming futures and tokens (but producers still have to be careful). If a reference cycle doesn't involve a token or future's source, it will be broken when the source is deallocated.
- **Documentation**: Useful doc comments on every method and type, that don't just repeat the name, covering corner cases and in some cases basic usage hints. No 'getting started' guides yet, though.

**Recent Changes**

- Version 1.
- Deprecated "TwistedOakCollapsingFutures.h" for "CollapsingFutures.h".
- Futures are now equatable (by current state then by will-end-up-in-same-state-with-same-value).

Installation
============

**Method #1: [CocoaPods](http://cocoapods.org/)**

1. In your [Podfile](http://guides.cocoapods.org/using/the-podfile.html), add `pod 'TwistedOakCollapsingFutures', '~> 1.0'`
2. Run `pod install` from the project directory
3. `#import "CollapsingFutures.h"` wherever you want to use futures, cancel tokens, or their category methods

**Method #2: Manual**

1. Download one of the [releases](https://github.com/Strilanc/ObjC-CollapsingFutures/releases), or clone the repo
2. Copy the source files from the src/ folder into your project
3. Have ARC enabled
4. `#import "CollapsingFutures.h"` wherever you want to use futures, cancel tokens, or their category methods


Usage
=====

**External Content**

- [Usage and benefits of collapsing futures](http://twistedoakstudios.com/blog/Post7149_collapsing-futures-in-objective-c)
- [Usage and benefits of cancellation tokens](http://twistedoakstudios.com/blog/Post7391_cancellation-tokens-and-collapsing-futures-for-objective-c)
- [How immortality detection works](http://twistedoakstudios.com/blog/Post7525_using-immortality-to-kill-accidental-callback-cycles)
- [Explanation and motivation for the 'monadic' design of futures (in C++)](http://bartoszmilewski.com/2014/02/26/c17-i-see-a-monad-in-your-future/)

**Using a Future**

The following code is an example of how to make a `TOCFuture` *do* something. Use `thenDo` to make things happen when the future succeeds, and `catchDo` to make things happen when it fails (there's also `finallyDo` for cleanup):

```objective-c
#import "CollapsingFutures.h"

// ask for the address book, which is asynchronous because IOS may ask the user to allow it
TOCFuture *futureAddressBook = SomeUtilityClass.asyncGetAddressBook;

// if the user refuses access to the address book (or something else goes wrong), log the problem
[futureAddressBook catchDo:^(id error) {
    NSLog("There was an error (%@) getting the address book.", error);
}];

// if the user allowed access, use the address book
[futureAddressBook thenDo:^(id arcAddressBook) {
    ABAddressBookRef addressBook = (__bridge ABAddressBookRef)arcAddressBook;
    
    ... do stuff with addressBook ...
}];
```

**Creating a Future**

How does the `asyncGetAddressBook` method from the above example control the future it returns?

In the simple case, where the result is already known, you use `TOCFuture futureWithResult:` or `TOCFuture futureWithFailure`.

When the result is not known right away, the class `TOCFutureSource` is used. It has a `future` property that completes after the source's `trySetResult` or `trySetFailure` methods are called.

Here's how `asyncGetAddressBook` is implemented:

```objective-c
#import "CollapsingFutures.h"

+(TOCFuture *) asyncGetAddressBook {
    CFErrorRef creationError = nil;
    ABAddressBookRef addressBookRef = ABAddressBookCreateWithOptions(NULL, &creationError);
    
    // did we fail right away? Then return an already-failed future
    if (creationError != nil) {
        return [TOCFuture futureWithFailure:(__bridge_transfer id)creationError];
    }
    
    // we need to make an asynchronous call, so we'll use a future source
    // that way we can return its future right away and fill it in later
    TOCFutureSource *resultSource = [FutureSource new];
        
    id arcAddressBook = (__bridge_transfer id)addressBookRef; // retain the address book in ARC land
    ABAddressBookRequestAccessWithCompletion(addressBookRef, ^(bool granted, CFErrorRef requestAccessError) {
        // time to fill in the future we returned
        if (granted) {
            [resultSource trySetResult:arcAddressBook];
        } else {
            [resultSource trySetFailure:(__bridge id)requestAccessError];
        }
    });
            
    return resultSource.future;
}
```

**Chaining Futures**

Just creating and using futures is useful, but not what makes them powerful. The true power is in transformative methods like  `then:` and `toc_thenAll` that both consume and produce futures. They make wiring up complicated asynchronous sequences look easy:

```objective-c
#import "CollapsingFutures.h"

+(TOCFuture *) sumOfFutures:(NSArray*)arrayOfFuturesOfNumbers {
    // we want all of the values to be ready before we bother summing
    TOCFuture* futureOfArrayOfNumbers = arrayOfFuturesOfNumbers.toc_thenAll;
    
    // once the array of values is ready, add up its entries to get the sum
    TOCFuture* futureSum = [futureOfArrayOfNumbers then:^(NSArray* numbers) {
        double total = 0;
        for (NSNumber* number in numbers) {
            total += number.doubleValue;
        }
        return @(total);
    }];
    
    // this future will eventually contain the sum of the eventual numbers in the input array
    // if any of the evetnual numbers fails, this future will end up failing as well
    return futureSum;
}
```

The ability to setup transformations to occur once futures are ready allows you to write truly asynchronous code, that doesn't block precious threads, with very little boilerplate and intuitive propagation of failures.

API Breakdown
=============

**TOCFuture**: *An eventual result.*

- `+futureWithResult:(id)resultValue`: Returns a future that has already succeeded with the given value. If the value is a future, collapse occurs and its result/failure is used instead.
- `+futureWithFailure:(id)failureValue`: Returns a future that has already failed with the given value. Variants for timeout and cancel failures work similarly.
- `+new`: Returns an immortal future. (Not very useful.)
- `+futureFromOperation:(id (^)(void))operation dispatchedOnQueue:(dispatch_queue_t)queue`: Dispatches an asynchronous operation, exposing the result as a future.
- `+futureFromOperation:(id(^)(void))operation invokedOnThread:(NSThread*)thread`: Runs an asynchronous operation, exposing the result as a future.
- `+futureWithResult:(id)resultValue afterDelay:(NSTimeInterval)delayInSeconds`: Returns a future the completes after a delay. An `unless:` variant allows the future to be cancelled and the timing stuff cleaned up.

- `+futureFromUntilOperation:withOperationTimeout:until:`: Augments an until-style asynchronous operation with a timeout, returning the may-timeout future. The operation is cancelled if the timeout expires before completion. The operation is cancelled and/or its result cleaned up when the token is cancelled.

- `+futureFromUnlessOperation:withOperationTimeout:`: Augments an unless-style asynchronous operation with a timeout, returning the may-timeout future. The operation is cancelled if the timeout expires before the operation completes. An `unless` variant allows the operation to also be cancelled if a token is cancelled before it completes.

- `cancelledOnCompletionToken`: Returns a `TOCCancelToken` that becomes cancelled when the future has succeeded or failed.

- `state`: Determines if the future is still able to be set (incomplete), failed, succeeded, flattening, or known to be immortal.

- `isIncomplete`: Determines if the future is still able to be set, flattening, or known to be immortal.

- `hasResult`: Determines if the future has succeeded with a result.

- `hasFailed`: Determines if the future has failed.

- `hasFailedWithCancel`: Determines if the future was cancelled, i.e. failed with a `TOCCancelToken` as its failure.

- `hasFailedWithTimeout`: Determines if the future timed out, i.e. failed with a `TOCTimeout` as its failure.

- `forceGetResult`: Returns the future's result, but raises an exception if the future didn't succeed with a result.

- `forceGetFailure`: Returns the future's result, but raises an exception if the future didn't fail.

- `finally[Do]:block [unless:token]`: Runs a callback when the future succeeds or fails. Passes the completed future into the block. The non-Do variants return a future that will eventually contain the result of evaluating the result-returning block.
- `then[Do]:block [unless:token]`: Runs a callback when the future succeeds. Passes the future's result into the block. The non-Do variants return a future that will eventually contain the result of evaluating the result-returning block, or else the same failure as the receiving future.
- `catch[Do]:block [unless:token]`: Runs a callback when the future fails. Passes the future's failure into the block. The non-Do variants return a future that will eventually contain the same result, or else the result of evaluating the result-returning block.
- `isEqualToFuture:(TOCFuture*)other`: Determines if this future is in the same state and, if completed, has the same result/failure as the other future.

- `unless:(TOCCancelToken*)unless`: Returns a future that will have the same result, unless the given token is cancelled first in which case it fails due to cancellation.

- 

**TOCFutureSource**: *Creates and controls a TOCFuture.*

- `+new`: Returns a new future source controlling a new future.

- `+futureSourceUntil:(TOCCancelToken*)untilCancelledToken`: Returns a new future source controlling a new future, wired to automatically fail with cancellation if the given token is cancelled before the future is set.

- `future`: Returns the future controlled by this source.

- `trySetResult:(id)result`: Sets the controlled future to succeed with the given value. If the result is a future, collapse occurs. Returns false if the future was already set, whereas the force variant raises an exception.

- `trySetFailure:(id)result`: Sets the controlled future to fail with the given value. Returns false if the future was already set, whereas the force variant raises an exception. Variants for cancellation and timeout work similarly.

**TOCCancelToken**: Notifies you when operations should be cancelled.

- `+cancelledToken`: Returns an already cancelled token.

- `+immortalToken`: Returns a token that will never be cancelled. Just a `[TOCCancelToken new]` token, but acts exactly like a nil cancel token.

- `state`: Determines if the cancel token is cancelled, still cancellable, or known to be immortal.

- `isAlreadyCancelled`: Determines if the cancel token is already cancelled.

- `canStillBeCancelled`: Determines if the cancel token is not cancelled and not known to be immortal.

- `whenCancelledDo:(TOCCancelHandler)cancelHandler`, `whenCancelledDo:(TOCCancelHandler)cancelHandler unless:(TOCCancelToken*)unlessCancelledToken`: Registers a void callback to run after the token is cancelled. Runs inline if already cancelled. The unless variant allows the callback to be removed if it has not run and is no longer needed (indicated by the other token being cancelled first).

- `+matchFirstToCancelBetween:(TOCCancelToken*)token1 and:(TOCCancelToken*)token2`: Returns a token that is the minimum of two tokens. It is cancelled as soon as either of them is cancelled.

- `+matchLastToCancelBetween:(TOCCancelToken*)token1 and:(TOCCancelToken*)token2`: Returns a token that is the maximum of two tokens. It is cancelled only when both of them is cancelled.

**TOCCancelTokenSource**: *Creates and controls a cancel token.*

- `+new`: Returns a new cancel token source that controls a new cancel token.

- `+cancelTokenSourceUntil:(TOCCancelToken*)untilCancelledToken`: Returns a cancel token source that controls a new cancel token, but wired to cancel automatically when the given token is cancelled.

- `token`: Returns the cancel token controlled by the source.

- `cancel`: Cancels the token controlled by the source. Does nothing if the token is already cancelled.

- `tryCancel`: Cancels the token controlled by the source, returning false if it was already cancelled.

**NSArray+**: *We are one. We are many. We are more.*

- `toc_thenAll`, `toc_thenAllUnless:(TOCCancelToken*)unless`: Converts from array-of-future to future-of-array. Takes an array of futures and returns a future that succeeds with an array of those futures' results. If any of the futures fails, the returned future fails. Example: `@[[TOCFuture futureWithResult:@1], [TOCFuture futureWithResult:@2]].toc_thenAll` evaluates to `[TOCFuture futureWithResult:@[@1, @2]]`.

- `toc_finallyAll`, `toc_finallyAllUnless:(TOCCancelToken*)unless`: Awaits the completion of many futures. Takes an array of futures and returns a future that completes with an array of the same futures, but only after they have all completed. Example: `@[[TOCFuture futureWithResult:@1], [TOCFuture futureWithFailure:@2]].toc_finallyAll` evaluates to `[TOCFuture futureWithResult:@[[TOCFuture futureWithResult:@1], [TOCFuture futureWithFailure:@2]]]`.

- `toc_orderedByCompletion`, `toc_orderedByCompletionUnless:(TOCCancelToken*)unless`: Returns an array with the "same" futures, except re-ordered so futures that will complete later will come later in the array. Example: `@[[TOCFutureSource new].future, [TOCFuture futureWithResult:@1]].toc_orderedByCompletion` returns `@[[TOCFuture futureWithResult:@1], [TOCFutureSource new].future]`.

- `toc_raceForWinnerLastingUntil:(TOCCancelToken*)untilCancelledToken`: Takes an array of `TOCUntilOperation` blocks. Each block is a cancellable asynchronous operation, returning a future and taking a cancel token that cancels the operations and/or cleans up the operation's result. The returned future completes with the result of the first operation to finish (or else all of their failures). The result of the returned future is cleaned up upon cancellation.

Development
===========

**How to Build:**

1. **Get Source Code**: [Clone this git repository to your machine](https://help.github.com/articles/fetching-a-remote).

2. **Get Dependencies**: [Have cocoa pods installed](http://guides.cocoapods.org/using/getting-started.html). Run `pod install` from the project directory.
	
3. **Open Workspace**: Open `CollapsingFutures.xworkspace` with XCode (not the project, the *workspace*). Run tests and confirm that they pass.
