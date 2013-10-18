#import <Foundation/Foundation.h>

typedef id (^TOCInternal_Projection)(id value);
typedef bool (^TOCInternal_Predicate)(id value);

@interface NSArray (TOCInternal_Functional)

-(NSArray*) map:(TOCInternal_Projection)projection;

-(NSArray*) where:(TOCInternal_Predicate)predicate;

-(bool) allItemsSatisfy:(TOCInternal_Predicate)predicate;

-(bool) allItemsAreKindOfClass:(Class)classInstance;

@end
