#import "JNNsUrlConnection.h"

#import "JFFURLConnectionParams.h"
#import "JFFLocalCookiesStorage.h"

#import "NSMutableURLRequest+CreateRequestWithURLParams.h"

#define NSURLConnectionDoesNotWorkWithLocalFiles

@implementation JNNsUrlConnection
{
    NSURLConnection* _nativeConnection;
    JFFURLConnectionParams* _params;
    NSRunLoop *_connectRunLoop;
}

//TODO: Test Connection with runloops!
-(void)dealloc
{
    [self cancel];
}

- (id)initWithURLConnectionParams:(JFFURLConnectionParams *)params
{
    NSParameterAssert(params);
    
    self = [super init];
    
    if (self) {
        self->_params = params;
        
#ifdef NSURLConnectionDoesNotWorkWithLocalFiles
        if (![self->_params.url isFileURL])
#endif
        {
            NSMutableURLRequest *request = [NSMutableURLRequest mutableURLRequestWithParams:params];
            
            NSURLConnection *nativeConnection = [[NSURLConnection alloc] initWithRequest:request
                                                                                delegate:self
                                                                        startImmediately:NO];
            
            //mm: Create runloop if need. Neccessary for call NSURLConnectionDelegate
            NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
            if (runLoop != [NSRunLoop mainRunLoop]) {
                self->_connectRunLoop = runLoop;
                [nativeConnection scheduleInRunLoop:runLoop forMode: NSDefaultRunLoopMode];
            }
            
            self->_nativeConnection = nativeConnection;
        }
    }
    
    return self;
}

#ifdef NSURLConnectionDoesNotWorkWithLocalFiles
- (void)processLocalFileWithPath:(NSString *)path
{
    NSError *error;
    //STODO read file in separate thread
    //STODO read big files by chunks
    NSData *data_ = [[NSData alloc]initWithContentsOfFile:path
                                                  options:0
                                                    error:&error];
    
    if (error) {
        [self connection:self->_nativeConnection
        didFailWithError:error];
    } else {
        NSHTTPURLResponse *response =
        [ [ NSHTTPURLResponse alloc ] initWithURL: self->_params.url
                                       statusCode: 200
                                      HTTPVersion: @"HTTP/1.1"
                                     headerFields: nil ];
        [self connection:self->_nativeConnection
      didReceiveResponse:response];
        
        [self connection:self->_nativeConnection
          didReceiveData:data_];
        
        [self connectionDidFinishLoading:self->_nativeConnection];
    }
}
#endif

#pragma mark -
#pragma mark JNUrlConnection
- (void)start
{
#ifdef NSURLConnectionDoesNotWorkWithLocalFiles
    if ( [ self->_params.url isFileURL ] ) {
        NSString* path_ = [ self->_params.url path ];
        [ self processLocalFileWithPath: path_ ];
        return;
    }
#endif
    [self->_nativeConnection start];
    
    if (self->_nativeConnection) {
        [self->_connectRunLoop run];
    }
}

- (void)cancel
{
    [self clearCallbacks];
    [self->_nativeConnection cancel];
    self->_nativeConnection = nil;
}

- (void)clearCallbacks
{
    [super clearCallbacks];

    if (self->_connectRunLoop) {
        [self->_nativeConnection unscheduleFromRunLoop:self->_connectRunLoop
                                               forMode:NSDefaultRunLoopMode];
    }
}

#pragma mark -
#pragma mark NSUrlConnectionDelegate
- (BOOL)assertConnectionMismatch:(NSURLConnection *)connection
{
    BOOL isConnectionMismatch = (connection != _nativeConnection);
    if (isConnectionMismatch) {
        NSLog( @"JNNsUrlConnection : connection mismatch" );
        NSAssert( NO, @"JNNsUrlConnection : connection mismatch" );
        return NO;
    }
    
    return YES;
}

- (void)connection:(NSURLConnection *)connection
didReceiveResponse:(NSHTTPURLResponse *)response
{
    if (![self assertConnectionMismatch:connection]) {
        return;
    }
    
    if (nil != self.didReceiveResponseBlock) {
        self.didReceiveResponseBlock(response);
    }
}

- (void)connection:(NSURLConnection *)connection
    didReceiveData:(NSData *)chunk
{
    if (![self assertConnectionMismatch:connection]) {
        return;
    }
    
    if (nil != self.didReceiveDataBlock) {
        self.didReceiveDataBlock(chunk);
    }
}

-(void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    if (![self assertConnectionMismatch:connection]) {
        return;
    }
    
    JFFDidFinishLoadingHandler finish = self.didFinishLoadingBlock;
    
    [self cancel];
    if (nil != finish) {
        finish(nil);
    }
}

- (void)connection:(NSURLConnection *)connection
  didFailWithError:(NSError *)error
{
    if (![ self assertConnectionMismatch:connection]) {
        return;
    }
    
    if (nil != self.didFinishLoadingBlock) {
        self.didFinishLoadingBlock(error);
        [self cancel];
    }
}

#pragma mark -
#pragma mark https
- (BOOL)connection:(NSURLConnection *)connection
canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace
{
    return [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];
}

//http://stackoverflow.com/questions/933331/how-to-use-nsurlconnection-to-connect-with-ssl-for-an-untrusted-cert
- (void)connection:(NSURLConnection *)connection
didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    NSString *authenticationMethod_ = challenge.protectionSpace.authenticationMethod;
    BOOL isTrustCheck = [authenticationMethod_ isEqualToString:NSURLAuthenticationMethodServerTrust];
    
    if (isTrustCheck) {
        BOOL isTrustedHost = NO;
        if (nil != self.shouldAcceptCertificateBlock) {
            isTrustedHost = self.shouldAcceptCertificateBlock(challenge.protectionSpace.host);
        }
        
        if (isTrustedHost) {
            NSURLCredential *cred = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
            
            [challenge.sender useCredential:cred
                 forAuthenticationChallenge:challenge];
        }
    }
    
    [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}

-(NSCachedURLResponse *)connection:(NSURLConnection *)connection
                 willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
    return nil;
}

@end
