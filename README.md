Collapsing Futures for Objective-C
==================================

This is a bare bones library implementing futures that automatically flatten when nested. A Future containing a Future containing an NSNumber CAN NOT happen, because it transparently flattens into a Future just containing an NSNumber.

Installation
============

Clone the repo and copy the four source files in the CollapsingFutures folder into an ARC-enabled project. The files:

(required)
- Future.h
- Future.m
(optional, just some utility methods)
- FutureExtra.h
- FutureExtra.m

Requires ARC.
