#import <Foundation/Foundation.h>
#import "TOCFutureAndSource.h"
#import "TOCCancelTokenAndSource.h"
#import "TOCFutureTypeDefs.h"

@interface Racer : NSObject

@property (readonly,nonatomic) TOCFuture* futureResult;
@property (readonly,nonatomic) TOCCancelTokenSource* canceller;

+(TOCFuture*) asyncRace:(NSArray*)starters
                  until:(TOCCancelToken*)untilCancelledToken;

@end
