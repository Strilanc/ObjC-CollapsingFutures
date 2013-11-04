#import <Foundation/Foundation.h>
#import "TOCInternal_Array+Functional.h"
#import "TOCInternal_BlockObject.h"
#import "TOCInternal_Racer.h"

#define TOC_require(expr) \
    if (!(expr)) \
        @throw([NSException exceptionWithName:NSInvalidArgumentException \
                                       reason:[NSString stringWithFormat:@"A precondition ( require(%@) ) was not satisfied. ", (@#expr)] \
                                     userInfo:nil])

#define TOC_force(expr) \
    if (!(expr)) \
        @throw([NSException exceptionWithName:NSInternalInconsistencyException \
                                       reason:[NSString stringWithFormat:@"A forced operation ( force(%@) ) failed to succeed.", (@#expr)] \
                                     userInfo:nil])

#define TOC_unexpectedEnum(expr) \
    @throw([NSException exceptionWithName:NSInternalInconsistencyException \
                                   reason:[NSString stringWithFormat:@"An unexpected enum value ( %@ = %d ) was encountered.", (@#expr), expr] \
                                 userInfo:nil])
