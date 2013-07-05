#import "JFFURLResponse.h"

#import "JFFUrlResponseLogger.h"

@implementation JFFURLResponse

@dynamic expectedContentLength;
@dynamic contentEncoding;


-(BOOL)hasContentLength
{
    return [ self->_allHeaderFields.allKeys containsObject: @"Content-Length" ];
}

- (unsigned long long)expectedContentLength
{
    id contentLengthObj_ = self->_allHeaderFields[@"Content-Length"];
    
    SEL ulongSelector_ = @selector(unsignedLongLongValue);
    if ( [ contentLengthObj_ respondsToSelector: ulongSelector_ ] )
    {
        return [ contentLengthObj_ unsignedLongLongValue ];
    }

    return (unsigned long long)[ contentLengthObj_ longLongValue ];
}

#pragma mark -
#pragma mark NSObject
-(NSString*)description
{
    NSString *custom = [JFFUrlResponseLogger descriptionStringForUrlResponse:self];
    return [[NSString alloc] initWithFormat:@"%@ \n   %@", [super description], custom];
}

-(NSString*)contentEncoding
{
    return self->_allHeaderFields[@"Content-Encoding"];
}

@end
