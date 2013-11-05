#import "TOCInternal_BlockObject.h"
#import "TOCInternal.h"

@implementation TOCInternal_BlockObject

+(TOCInternal_BlockObject*) voidBlock:(void(^)(void))block {
    TOC_require(block != nil);

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
    TOC_require(block != nil);

    if (thread == [NSThread currentThread]) {
        block();
        return;
    }
    
    TOCInternal_BlockObject* blockObject = [TOCInternal_BlockObject voidBlock:block];
    [blockObject performSelector:blockObject.runSelector
                        onThread:thread
                      withObject:block
                   waitUntilDone:NO];
}
+(void) performBlockOnNewThread:(void(^)(void))block {
    TOC_require(block != nil);
    
    TOCInternal_BlockObject* blockObject = [TOCInternal_BlockObject voidBlock:block];
    [NSThread detachNewThreadSelector:blockObject.runSelector toTarget:blockObject withObject:nil];
}

@end
