#import "TOCInternal_OnDeallocObject.h"
#import "TOCInternal.h"

@implementation TOCInternal_OnDeallocObject {
@private void (^block)(void);
}

+(TOCInternal_OnDeallocObject*) onDeallocDo:(void(^)(void))block {
    TOCInternal_need(block != nil);
    TOCInternal_OnDeallocObject* obj = [TOCInternal_OnDeallocObject new];
    obj->block = block;
    return obj;
}

-(void)poke {
    // this method is called from inside closures that want to keep a reference to this object
}

-(void)cancelDeallocAction {
    block = nil;
}

-(void)dealloc {
    if (block != nil) block();
}

@end
