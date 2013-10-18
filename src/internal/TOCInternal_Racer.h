#import <Foundation/Foundation.h>
#import "TOCCancelTokenAndSource.h"
#import "TOCFutureAndSource.h"
#import "TOCFutureTypeDefs.h"

@interface TOCInternal_Racer : NSObject

@property (readonly,nonatomic) TOCFuture* futureResult;
@property (readonly,nonatomic) TOCCancelTokenSource* canceller;

+(TOCFuture*) asyncRace:(NSArray*)starters
                  until:(TOCCancelToken*)untilCancelledToken;

@end
