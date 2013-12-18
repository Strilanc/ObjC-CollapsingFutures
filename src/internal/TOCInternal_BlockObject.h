#import <Foundation/Foundation.h>

@interface TOCInternal_BlockObject : NSObject
+(TOCInternal_BlockObject*) voidBlock:(void(^)(void))block;
-(void)run;
-(SEL)runSelector;
+(void) performBlock:(void(^)(void))block onThread:(NSThread*)thread;
+(void) performBlockOnNewThread:(void(^)(void))block;
@end
