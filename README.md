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

Development
===========

**How to Build:**

1. **Get Source Code**: [Clone this git repository to your machine](https://help.github.com/articles/fetching-a-remote).

2. **Get Dependencies**: [Have cocoa pods installed](http://guides.cocoapods.org/using/getting-started.html). Run `pod install` from the project directory.
	
3. **Open Workspace**: Open `CollapsingFutures.xworkspace` with XCode (not the project, the *workspace*). Run tests and confirm that they pass.
