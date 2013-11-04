Twisted Oak Collapsing Futures
==============================

This is a library implementing [futures](https://en.wikipedia.org/wiki/Future_%28programming%29) in Objective-C, featuring:

- **Types**: `TOCFuture` to represent eventual results, `TOCCancelToken` to propagate cancellation notifications, `TOCFutureSource` to produce and control an eventual result, and `TOCCancelTokenSource` to produce and control a cancel token.
- **Automatic Collapsing**: You never have to worry about forgetting to unwrap or flatten a doubly-eventual future. A `[TOCFuture futureWithResult:[TOCFuture futureWithResult:@1]]` is automatically a `[TOCFuture futureWithResult:@1]`.
- **Sticky Main Thread**: Callbacks registered from the main thread will get back on the main thread before executing.  Makes UI work much easier.
- **Cancellable Operations**: All asynchronous operations have variants that can be cancelled by cancelling the `TOCCancelToken` passed to the operation's `until:` or `unless:` parameter.
- **Immortality Detection**: It is impossible to create new space leaks by consuming futures and tokens (but producers still have to be careful). If a reference cycle doesn't involve a token or future's source, it will be broken when the source is deallocated.
- **Documentation**: Useful doc comments on every method and type, that don't just repeat the name, covering corner cases and in some cases basic usage hints. No 'getting started' guides yet, though.

Installation
============

**Method #1: [CocoaPods](http://cocoapods.org/)**

1. In your [Podfile](http://docs.cocoapods.org/podfile.html), add `pod 'TwistedOakCollapsingFutures'`
2. Consider [versioning](http://docs.cocoapods.org/guides/dependency_versioning.html), like: `pod 'TwistedOakCollapsingFutures', '~> 0.7`
3. Run `pod install`
4. `#import "TwistedOakCollapsingFutures.h"` wherever you want to access the library's types or methods



**Method #2: Manual**

1. Download one of the [releases](https://github.com/Strilanc/ObjC-CollapsingFutures/releases), or clone the repo
2. Copy the source files from the src/ folder into your project
3. Have ARC enabled
4. `#import "TwistedOakCollapsingFutures.h"` wherever you want to access the library's types or methods


Usage
=====

Blog posts:

- [Usage and benefits of collapsing futures](http://twistedoakstudios.com/blog/Post7149_collapsing-futures-in-objective-c)
- [Usage and benefits of cancellation tokens](http://twistedoakstudios.com/blog/Post7391_cancellation-tokens-and-collapsing-futures-for-objective-c)
- [How immortality detection works](http://twistedoakstudios.com/blog/Post7525_using-immortality-to-kill-accidental-callback-cycles)

A consumer using an asynchronous utility method that returns a future:

```objective-c
#import "TwistedOakCollapsingFutures.h"

TOCFuture* futureAddressBook = [AsyncUtil asyncRequestAndGetIOSAddressBook];
[futureAddressBook catchDo:^(id error) {
    NSLog("There was an error (I hope the user didn't deny access!): %@", error);
}];
[futureAddressBook thenDo:^(id addressBook) {
    // there's no NS type for address book, so have to cast it out
    ABAddressBookRef cfAddressBook = (__bridge ABAddressBookRef)addressBook;
        
    ... do stuff with cfAddressBook ...
}];
```

Producing that asynchronous address book, by using existing methods to control a future source:

```objective-c
#import "TwistedOakCollapsingFutures.h"

+(TOCFuture*) asyncRequestAndGetIOSAddressBook {
    CFErrorRef creationError = nil;
    ABAddressBookRef addressBookRef = ABAddressBookCreateWithOptions(NULL, &creationError);
    assert((addressBookRef == nil) == (creationError != nil));
    if (creationError != nil) {
        return [TOCFuture futureWithFailure:(__bridge_transfer id)creationError];
    }
    
    TOCFutureSource *futureAddressBookSource = [FutureSource new];
        
    id addressBook = (__bridge_transfer id)addressBookRef;
    ABAddressBookRequestAccessWithCompletion(addressBookRef, ^(bool granted, CFErrorRef requestAccessError) {
        if (granted) {
            [futureAddressBookSource trySetResult:addressBook];
        } else {
            [futureAddressBookSource trySetFailure:(__bridge id)requestAccessError];
        }
    });
            
    return futureAddressBookSource;
}
```
