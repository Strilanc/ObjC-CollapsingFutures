#import "TOCInternal.h"

@implementation NSArray (TOCInternal_Functional)

-(NSArray*) map:(TOCInternal_Projection)projection {
    TOC_require(projection != nil);
    
    NSMutableArray* results = [NSMutableArray arrayWithCapacity:self.count];
    for (id item in self) {
        id projectedItem = projection(item);
        TOC_require(projectedItem != nil);
        [results addObject:projectedItem];
    }
    
    return [results copy]; // remove mutability
}

-(NSArray*) where:(TOCInternal_Predicate)predicate {
    TOC_require(predicate != nil);
    
    NSMutableArray* results = [NSMutableArray arrayWithCapacity:self.count];
    for (id item in self) {
        if (predicate(item)) {
            [results addObject:item];
        }
    }
    
    return [results copy]; // remove mutability
}

-(bool) allItemsSatisfy:(TOCInternal_Predicate)predicate {
    TOC_require(predicate != nil);
    
    for (id item in self) {
        if (!predicate(item)) {
            return false;
        }
    }
    return true;
}

-(bool) allItemsAreKindOfClass:(Class)classInstance {
    TOC_require(classInstance != nil);
    return [self allItemsSatisfy:^bool(id value) { return [value isKindOfClass:classInstance]; }];
}

@end
