#import <Foundation/Foundation.h>

@interface TOCInternal_BlockObject : NSObject { @public void (^block)(void); }
+(TOCInternal_BlockObject*) voidBlock:(void(^)(void))block;
-(void)run;
-(SEL)runSelector;
+(void) performBlock:(void(^)(void))block onThread:(NSThread*)thread;
@end
