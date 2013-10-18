#import "TOCInternal_BlockObject.h"

@implementation TOCInternal_BlockObject

+(TOCInternal_BlockObject*) voidBlock:(void(^)(void))block {
    TOCInternal_BlockObject* b = [TOCInternal_BlockObject new];
    b->block = block;
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
    
    TOCInternal_BlockObject* voidBlock = [TOCInternal_BlockObject voidBlock:block];
    [voidBlock performSelector:[voidBlock runSelector]
                      onThread:thread
                    withObject:block
                 waitUntilDone:NO];
}

@end
