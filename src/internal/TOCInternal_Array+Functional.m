#import "TOCInternal.h"

@implementation NSArray (TOCInternal_Functional)

-(NSArray*) map:(TOCInternal_Projection)projection {
    TOCInternal_need(projection != nil);
    
    NSMutableArray* results = [NSMutableArray arrayWithCapacity:self.count];
    for (id item in self) {
        id projectedItem = projection(item);
        TOCInternal_need(projectedItem != nil);
        [results addObject:projectedItem];
    }
    
    return [results copy]; // remove mutability
}

-(NSArray*) where:(TOCInternal_Predicate)predicate {
    TOCInternal_need(predicate != nil);
    
    NSMutableArray* results = [NSMutableArray arrayWithCapacity:self.count];
    for (id item in self) {
        if (predicate(item)) {
            [results addObject:item];
        }
    }
    
    return [results copy]; // remove mutability
}

-(bool) allItemsSatisfy:(TOCInternal_Predicate)predicate {
    TOCInternal_need(predicate != nil);
    
    for (id item in self) {
        if (!predicate(item)) {
            return false;
        }
    }
    return true;
}

-(bool) allItemsAreKindOfClass:(Class)classInstance {
    TOCInternal_need(classInstance != nil);
    return [self allItemsSatisfy:^bool(id value) { return [value isKindOfClass:classInstance]; }];
}

@end
