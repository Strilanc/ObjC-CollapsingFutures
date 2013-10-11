Collapsing Futures for Objective-C
==================================

This is a bare bones library implementing futures that automatically flatten when nested. A Future containing a Future containing an NSNumber CAN NOT happen, because it transparently flattens into a Future just containing an NSNumber.

Usage is discussed in [this blog post](http://twistedoakstudios.com/blog/Post7149_collapsing-futures-in-objective-c).

Installation
============

**Method #1: CocoaPods**

Example podfile line:

    pod 'TwistedOakCollapsingFutures', :podspec => 'https://raw.github.com/Strilanc/ObjC-CollapsingFutures/master/TwistedOakCollapsingFutures.podspec'

1. Depend on the podspec from this repo
2. Import TwistedOakCollapsingFutures.h wherever you want to use the TOCFuture and TOCFutureSource types

**Method #2: Manual**

1. Clone the repo
2. Copy the source files from the src/ folder into your project
3. Have ARC enabled
4. Import TwistedOakCollapsingFutures.h wherever you want to use the TOCFuture and TOCFutureSource types
