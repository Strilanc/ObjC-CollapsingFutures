#import "Internal.h"

@implementation VoidBlock

+(VoidBlock*) voidBlock:(void(^)(void))block {
    VoidBlock* b = [VoidBlock new];
    b->block = [block copy];
    return b;
}
-(void)run {
    block();
}
-(SEL)runSelector {
    return @selector(run);
}
+(void) performBlock:(void(^)(void))block onThread:(NSThread*)thread {
    if (thread == [NSThread currentThread]) {
        block();
        return;
    }
    
    VoidBlock* voidBlock = [VoidBlock voidBlock:block];
    [voidBlock performSelector:[voidBlock runSelector]
                      onThread:thread
                    withObject:block
                 waitUntilDone:NO];
}

@end
