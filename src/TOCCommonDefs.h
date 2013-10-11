#define require(expr) \
    if (!(expr)) \
        @throw([NSException exceptionWithName:NSInvalidArgumentException \
                                       reason:[NSString stringWithFormat:@"Precondition failed: require(%@)", (@#expr)] \
                                     userInfo:nil])
