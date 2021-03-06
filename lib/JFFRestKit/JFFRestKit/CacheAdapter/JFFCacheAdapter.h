#import <JFFRestKit/JFFRestKitCache.h>

#import <Foundation/Foundation.h>

@protocol JFFCacheDB;

typedef id<JFFCacheDB>(^JFFCacheFactory)(void);

@interface JFFCacheAdapter : NSObject <JFFRestKitCache>

+ (instancetype)newCacheAdapterWithCacheFactory:(JFFCacheFactory)cacheFactory
                                 cacheQueueName:(NSString *)cacheQueueName;

@end
