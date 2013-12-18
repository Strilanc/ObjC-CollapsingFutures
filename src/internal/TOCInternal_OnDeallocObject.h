#import <Foundation/Foundation.h>

@interface TOCInternal_OnDeallocObject : NSObject

+(TOCInternal_OnDeallocObject*) onDeallocDo:(void(^)(void))block;

-(void)poke;

-(void)cancelDeallocAction;

@end
