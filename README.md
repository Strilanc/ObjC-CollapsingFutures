Collapsing Futures for Objective-C
==================================

This is a library implementing futures in Objective-C, featuring:

- **Types**: `TOCFuture`, `TOCFutureSource`, `TOCCancelToken`, `TOCCancelTokenSource`
- **Collapsing**: Automatic flattening. You never have to worry about how many times you need to unwrap/flatten a future. A `[TOCFuture futureWithResult:[TOCFuture futureWithResult:@1]]` is automatically a `[TOCFuture futureWithResult:@1]`.
- **Cancellation**: Almost all asynchronous operations have a variant that accepts a `TOCCancelToken`. When the cancel token is cancelled, the operation immediately cleans up and completes with a cancellation failure (if it didn't already finish).
- **Immortality**: When a future or cancel token's source is lost, they are marked as immortal. This also occurs if a future's result cycles back to itself (preventing flattening from completing). Immortal futures and tokens discard their callbacks. This makes it a lot harder to accidentally create a self-sustaining reference cycle (you have to involve the sources).
- **Documentation**: Useful doc comments on every method and type, that don't just repeat the name, covering corner cases and in some cases basic usage hints. No 'getting started' guides yet, though.


Basic usage is discussed in [this blog post](http://twistedoakstudios.com/blog/Post7149_collapsing-futures-in-objective-c).

Installation
============

**Method #1: CocoaPods**

Example podfile line (for 'bleeding edge' instead of a particular release):

    pod 'TwistedOakCollapsingFutures', :podspec => 'https://raw.github.com/Strilanc/ObjC-CollapsingFutures/master/TwistedOakCollapsingFutures.podspec'

1. Depend on the podspec from this repo
2. Import `TwistedOakCollapsingFutures.h` wherever you want to access the library's types or methods

**Method #2: Manual**

1. Download one of the [releases](https://github.com/Strilanc/ObjC-CollapsingFutures/releases), or clone the repo
2. Copy the source files from the src/ folder into your project
3. Have ARC enabled
4. Import `TwistedOakCollapsingFutures.h` wherever you want to access the library's types or methods.
