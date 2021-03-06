#import "JFFDownloadItem.h"

#import "JFFFileManager.h"
#import "JFFURLConnection.h"
#import "NSMutableSet+DownloadManager.h"
#import "JFFDownloadItemDelegate.h"
#import "JFFURLResponse.h"
#import "JFFURLConnectionParams.h"

#import "JFFTrafficCalculator.h"
#import "JFFTrafficCalculatorDelegate.h"
#import "NSMutableDictionary+DownloadingFileInfo.h"

#import <JFFAsyncOperations/CachedAsyncOperations/NSObject+AsyncPropertyReader.h>
#import <JFFAsyncOperations/JFFAsyncOperationHelpers.h>
#import <JFFAsyncOperations/Helpers/JFFCancelAsyncOperationBlockHolder.h>

static JFFMutableAssignArray *downloadItems = nil;

long long JFFUnknownFileLength = NSURLResponseUnknownLength;

@interface JFFDownloadItem () <JFFTrafficCalculatorDelegate>

@property (nonatomic) NSURL    *url;
@property (nonatomic) NSString *localFilePath;
@property (nonatomic) float downlodingSpeed;
@property (nonatomic) unsigned long long fileLength;
@property (nonatomic) unsigned long long downloadedFileLength;
@property (nonatomic) NSNull *downloadedFlag;
@property (nonatomic, copy) JFFCancelAsyncOperation stopBlock;

@end

@implementation JFFDownloadItem
{
    JFFTrafficCalculator *_trafficCalculator;
    FILE *_file;
    float _previousProgress;
    JFFMulticastDelegate< JFFDownloadItemDelegate > *_multicastDelegate;
}

@dynamic downloadedFlag;
@dynamic downloaded;
@dynamic activeDownload;

- (void)dealloc
{
    [self closeFile];
}

- (unsigned long long)fileSizeForPath:(NSString *)filePath
{
    NSDictionary *dict = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
    return [dict fileSize];
}

- (instancetype)initWithURL:(NSURL *)url
              localFilePath:(NSString *)localFilePath
{
    self = [super init];
    
    if (self) {
        self.url = url;
        self.localFilePath = localFilePath;
        self.downloadedFileLength = [self fileSizeForPath:localFilePath];
        _multicastDelegate = (JFFMulticastDelegate< JFFDownloadItemDelegate >*)[JFFMulticastDelegate new];
        
        if (self.downloaded) {
            
            self.fileLength = self.downloadedFileLength;
        } else {
            self.fileLength = [NSMutableDictionary fileLengthForDestinationURL:url];
        }
    }
    
    return self;
}

- (JFFTrafficCalculator *)trafficCalculator
{
   if (!_trafficCalculator) {
      _trafficCalculator = [[JFFTrafficCalculator alloc] initWithDelegate:self];
   }
   return _trafficCalculator;
}

- (void)closeFile
{
    if (_file) {
        
        fclose(_file);
        _file = 0;
    }
}

- (NSNull *)downloadedFlag
{
    BOOL downloded_ = [NSMutableSet containsDownloadedFileWithPath:self.localFilePath];
    return downloded_ ? [NSNull new] : nil;
}

- (void)setDownloadedFlag:(NSNull *)downloadedFlag
{
    if (downloadedFlag)
        [NSMutableSet addDownloadedFileWithPath:self.localFilePath];
}

- (float)progress
{
    unsigned long long fileLength = self.fileLength;
    static const unsigned long long castecUnknownLength = (unsigned long long)NSURLResponseUnknownLength;
    
    BOOL isUnknownLength = ( fileLength == castecUnknownLength );
    BOOL isZeroLength = ( 0.f == fileLength );
    
    if (isUnknownLength) {
        return 0.f;
    }
    else if (isZeroLength) {
        return 1.f;
    }
    
    float fFileLength = (float)self.fileLength;
    float fDownloadedFileLength = (float)self.downloadedFileLength;
    
    float result = fDownloadedFileLength / fFileLength;
    return result;
}

+ (BOOL)checkNotAlreadyUsedLocalPath:(NSString *)localFilePath
                                 url:(NSURL *)url
                               error:(NSError **)outError
{
    BOOL result = ![downloadItems any:^BOOL(id object) {
        JFFDownloadItem *item_ = object;
        return ![item_.url isEqual:url]
            && [ item_.localFilePath isEqualToString:localFilePath];
    }];
    
    if (!result && outError) {
        
        static NSString *const errorDescription = @"Invalid arguments. This \"local path\" used for another url";
        *outError = [JFFError newErrorWithDescription:errorDescription];
    }
    
    return result;
}

+ (instancetype)downloadItemWithURL:(NSURL *)url
                      localFilePath:(NSString *)localFilePath
                              error:(NSError **)outError
{
    if (![self checkNotAlreadyUsedLocalPath:localFilePath url:url error:outError])
        return nil;
    
    id result = [downloadItems firstMatch: ^BOOL(id object) {
        JFFDownloadItem *item = object;
        return [item.url isEqual:url]
            && [item.localFilePath isEqualToString:localFilePath];
    } ];
    
    if (!result) {
        
        result = [[self alloc] initWithURL:url localFilePath:localFilePath];
        if (!downloadItems) {
            downloadItems = [JFFMutableAssignArray new];
        }
        [downloadItems addObject:result];
    }

    return result;
}

- (BOOL)downloaded
{
    return self.downloadedFlag != nil;
}

- (BOOL)activeDownload
{
    return self.stopBlock != nil;
}

- (void)start
{
    if (self.stopBlock)
        return;
    
    [self fileLoader](nil, nil, ^(id result, NSError *error){
        
        [error writeErrorWithJFFLogger];
    });
}

- (void)stop
{
    JFFCancelAsyncOperation stopBlock = [self.stopBlock copy];
    if (stopBlock) {
        self.stopBlock = nil;
        stopBlock(YES);
    }
}

- (void)removeDownload
{
    [self stop];
    [NSMutableSet removeDownloadedFileWithPath:self.localFilePath];
}

+ (BOOL)removeDownloadForURL:(NSURL *)url
               localFilePath:(NSString *)localFilePath
                       error:(NSError **)outError
{
    @autoreleasepool
    {
        JFFDownloadItem *item = [self downloadItemWithURL:url localFilePath:localFilePath error:outError];
        [item removeDownload];
        return item != nil;
    }
    
    return NO;
}

- (void)addDelegate:(id<JFFDownloadItemDelegate>)delegate
{
    [_multicastDelegate addDelegate:delegate];
}

- (void)removeDelegate:(id<JFFDownloadItemDelegate>)delegate
{
    [_multicastDelegate removeDelegate:delegate];
}

#pragma mark JFFURLConnection callbacks

- (void)finalizeLoading
{
    self.stopBlock = nil;
    [self closeFile];
    [_trafficCalculator stop];
    _trafficCalculator = nil;
}

- (void)notifyFinishWithError:(NSError *)error
{
    if (error)
        [_multicastDelegate didFailLoadingOfDownloadItem:self error:error];
    else
        [_multicastDelegate didFinishLoadingOfDownloadItem:self];
}

- (void)didFinishLoadedWithError:(NSError *)error
{
    id downloadedFlag = error ? nil : [NSNull new];
    self.downloadedFlag = downloadedFlag;
    
    [self finalizeLoading];
}

- (void)didCancelWithFlag:(BOOL)canceled
           cancelCallback:(JFFCancelAsyncOperationHandler)cancelCallback
{
    NSParameterAssert(canceled);
    [self finalizeLoading];
    
    [_multicastDelegate didCancelLoadingOfDownloadItem:self];
    
    if (cancelCallback)
        cancelCallback(canceled);
}

- (void)didReceiveData:(NSData *)data
       progressHandler:(JFFAsyncOperationProgressHandler)progressCallback
{
    if (!_trafficCalculator)
        [self.trafficCalculator startLoading];
    
    if (!_file)
        _file = [JFFFileManager createFileForPath:self.localFilePath];
    
    fwrite([data bytes], 1, [data length], _file);
    fflush(_file );
    
    [self.trafficCalculator bytesReceived:data.length];
    
    self.downloadedFileLength += data.length;
    
    if ((self.progress - _previousProgress) > 0.005f) {
        _previousProgress = self.progress;
        [_multicastDelegate didProgressChangeForDownloadItem:self];
    }
    
    if (progressCallback)
        progressCallback(self);
}

- (void)didReceiveResponse:(JFFURLResponse *)response
{
    self.fileLength = self.downloadedFileLength + response.expectedContentLength;
}

- (JFFAsyncOperation)fileLoader
{
    JFFAsyncOperation loader = ^JFFCancelAsyncOperation(JFFAsyncOperationProgressHandler progressCallback,
                                                         JFFCancelAsyncOperationHandler cancelCallback,
                                                         JFFDidFinishAsyncOperationHandler doneCallback)
    {
        NSString *range = [[NSString alloc] initWithFormat:@"bytes=%qu-", self.downloadedFileLength];
        NSDictionary *headers = @{ @"Range" : range };
        
        JFFURLConnectionParams *params = [JFFURLConnectionParams new];
        params.url     = self.url;
        params.headers = headers;
        JFFURLConnection *connection = [[JFFURLConnection alloc] initWithURLConnectionParams:params];
        
        progressCallback = [ progressCallback copy ];
        connection.didReceiveDataBlock = ^(NSData *data) {
            [self didReceiveData:data
                 progressHandler:progressCallback];
        };
        
        doneCallback = [doneCallback copy];
        connection.didFinishLoadingBlock = ^(NSError *error) {
            
            [self didFinishLoadedWithError:error];
            
            if (doneCallback)
                doneCallback(error?nil:[NSNull new], error);
        };
        
        connection.didReceiveResponseBlock = ^(id/*< JNUrlResponse >*/ response) {
            [self didReceiveResponse:response];
        };
        
        JFFCancelAsyncOperationBlockHolder *cancelCallbackBlockHolder = [JFFCancelAsyncOperationBlockHolder new];
        cancelCallback = [cancelCallback copy];
        JFFCancelAsyncOperationHandler cancelCallbackWrapper = ^(BOOL canceled)
        {
            [self didCancelWithFlag:canceled cancelCallback:cancelCallback];
        };
        cancelCallbackBlockHolder.cancelBlock = cancelCallbackWrapper;
        
        [connection start];
        
        [_multicastDelegate didProgressChangeForDownloadItem:self];
        
        self.stopBlock = ^void(BOOL canceled)
        {
            if (canceled)
                [connection cancel];
            else
                NSCAssert(NO, @"pass canceled as YES only");
            
            cancelCallbackBlockHolder.onceCancelBlock(canceled);
        };
        return self.stopBlock;
    };
    
    loader = [self asyncOperationForPropertyWithName:NSStringFromSelector(@selector(downloadedFlag))
                                      asyncOperation:loader];
    
    JFFDidFinishAsyncOperationHandler didFinishOperation = ^void(id result, NSError *error) {
        [self notifyFinishWithError:error];
    };
    return asyncOperationWithFinishCallbackBlock(loader,
                                                 didFinishOperation);
}

#pragma mark JFFTrafficCalculatorDelegate

- (void)trafficCalculator:(JFFTrafficCalculator *)trafficCalculator
   didChangeDownloadSpeed:(float)speed
{
    self.downlodingSpeed = speed;
    [_multicastDelegate didProgressChangeForDownloadItem:self];
}

@end
