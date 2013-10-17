#import <Foundation/Foundation.h>

typedef id (^Projection)(id value);
typedef bool (^Predicate)(id value);

@interface NSArray (Functional)

-(NSArray*) map:(Projection)projection;

-(NSArray*) where:(Predicate)predicate;

-(bool) allItemsSatisfy:(Predicate)predicate;

-(bool) allItemsAreKindOfClass:(Class)classInstance;

@end
