#import <Foundation/Foundation.h>

@interface NSHTTPCookie (matchesURL)

- (BOOL)matchesURL:(NSURL *)url;

@end
