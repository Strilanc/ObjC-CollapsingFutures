#import "TOCInternal_Array+Functional.h"
#import "TOCInternal.h"

@implementation NSArray (Functional)

-(NSArray*) map:(Projection)projection {
    require(projection != nil);
    
    NSMutableArray* results = [NSMutableArray arrayWithCapacity:self.count];
    for (id item in self) {
        id projectedItem = projection(item);
        require(projectedItem != nil);
        [results addObject:projectedItem];
    }
    
    return [results copy]; // remove mutability
}

-(NSArray*) where:(Predicate)predicate {
    require(predicate != nil);
    
    NSMutableArray* results = [NSMutableArray arrayWithCapacity:self.count];
    for (id item in self) {
        if (predicate(item)) {
            [results addObject:item];
        }
    }
    
    return [results copy]; // remove mutability
}

-(bool) allItemsSatisfy:(Predicate)predicate {
    require(predicate != nil);
    
    for (id item in self) {
        if (!predicate(item)) {
            return false;
        }
    }
    return true;
}

-(bool) allItemsAreKindOfClass:(Class)classInstance {
    require(classInstance != nil);
    return [self allItemsSatisfy:^bool(id value) { return [value isKindOfClass:classInstance]; }];
}

@end
