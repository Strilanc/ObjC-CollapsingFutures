#import <Foundation/Foundation.h>

#define require(expr) \
    if (!(expr)) \
        @throw([NSException exceptionWithName:NSInvalidArgumentException \
                                       reason:[NSString stringWithFormat:@"A precondition ( require(%@) ) was not satisfied. ", (@#expr)] \
                                     userInfo:nil])

#define force(expr) \
    if (!(expr)) \
        @throw([NSException exceptionWithName:NSInternalInconsistencyException \
                                       reason:[NSString stringWithFormat:@"A forced operation ( force(%@) ) failed to succeed.", (@#expr)] \
                                     userInfo:nil])

@interface VoidBlock : NSObject { @public void (^block)(void); }
+(VoidBlock*) voidBlock:(void(^)(void))block;
-(void)run;
-(SEL)runSelector;
+(void) performBlock:(void(^)(void))block onThread:(NSThread*)thread;
@end
