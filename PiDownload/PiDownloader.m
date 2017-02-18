//
//  PiDownloader.m
//  PiDownload
//
//  Created by 江派锋 on 2017/2/16.
//  Copyright © 2017年 Coder.Pi. All rights reserved.
//

#import "PiDownloader.h"
#import "PiDownloadLogger.h"
#import "PiDownloadTaskImp.h"
#import "PiDownloadStorage.h"

#ifdef PIDOWNLOAD_IOS
#import "Reachability.h"
#endif

@interface PiDownloader ()<NSURLSessionDownloadDelegate, PiDownloadTaskCreator>
#ifdef PIDOWNLOAD_IOS
@property (nonatomic, strong) NSMutableArray *waitNetworkTaskList;
#endif
@property (nonatomic, strong) PiDownloadStorage *storage;
@property (nonatomic, strong) NSURLSession *backgroundSession;
@end

@implementation PiDownloader

// MARK: - Init
+ (NSString *) DefaultIdentifier
{
    return [NSString stringWithFormat:@"%@.PiDownload", [[NSBundle mainBundle] bundleIdentifier]];
}

+ (NSString *) FormatIdentifier:(NSString *)identifier
{
    return [NSString stringWithFormat:@"%@.%@", self.DefaultIdentifier, identifier];
}

+ (PiDownloader *) SharedObject
{
    static PiDownloader *s_shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_shared = [[PiDownloader alloc] initWithIdentifier:@"Shared"];
    });
    return s_shared;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype) initWithIdentifier:(NSString *)identifier
{
    self = [super init];
    if (self)
    {
        _identifier = [self.class FormatIdentifier:identifier];
        PI_INFO_LOG(@"Init Downloader With Identifier : %@", _identifier);
        [self initBgSession];
        _storage = [PiDownloadStorage storageWithIdentifier:_identifier];
        [self readyTaskList];
#ifdef PIDOWNLOAD_IOS
        [self watchNetwork];
#endif
    }
    return self;
}

- (void) initBgSession
{
    assert(_backgroundSession == nil);
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:_identifier];
    _backgroundSession = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:[NSOperationQueue mainQueue]];
}

// MARK: - Task
- (PiDownloadTask *) addTaskWithUrl:(NSString *)urlString
{
    PiDownloadTask *task = [_storage addTaskWithUrl:urlString];
    task.taskCreator = self;
    [task resume];
    return task;
}

- (BOOL) removeTask:(PiDownloadTask *)task
{
    if (task == nil)
    {
        PI_WARNING_LOG(@"Remove nil task");
        return NO;
    }
    
    PI_INFO_LOG(@"Remove task with url : %@", task.downloadURL);
    if (task.state == PiDownloadTaskState_Running)
    {
        [task cancel];
    }
    [_storage removeTask:task];
    return YES;
}

- (BOOL) removeTaskWithUrl:(NSString *)urlString
{
    PiDownloadTask *task = [_storage findTaskWithUrlString:urlString];
    return [self removeTask:task];
}

- (NSArray<PiDownloadTask *> *) tasks
{
    return _storage.tasks;
}

- (void) readyTaskList
{
    for (PiDownloadTask *task in _storage.tasks)
    {
        task.taskCreator = self;
        [task ready];
        
        if (task.state == PiDownloadTaskState_Running)
        {
            if (_config.autoStartOnLaunch)
            {
                [task resume];
            }
            else
            {
                task.state = PiDownloadTaskState_Suspend;
            }
        }
    }
}

// MARK: - PiDownloadTaskCreator
- (NSURLSessionDownloadTask *) onDownloadTaskCreate:(PiDownloadTask *)task
{
    if ([task isValidresumeData])
    {
        return [_backgroundSession downloadTaskWithResumeData:task.resumeData];
    }
    return [_backgroundSession downloadTaskWithURL:[NSURL URLWithString:task.downloadURL]];
}

// MARK: - NSURLSessionDownloadDelegate
- (void) URLSession:(NSURLSession *)session task:(NSURLSessionTask *)downloadTask didCompleteWithError:(NSError *)error
{
    if (error == nil) return;
    
    PI_INFO_LOG(@"Got download error");
    PiDownloadTask *task = [_storage findTaskWithId:downloadTask.taskIdentifier];
    if (task == nil) return;
    
    if (error.code == NSURLErrorCancelled)
    {
        if (task.state == PiDownloadTaskState_Canceling)
        {
            [_storage removeTask:task];
            PI_INFO_LOG(@"Cancel Download Task with URL : %@", task.downloadURL);
        }
    }
    else
    {
        task.resumeData = error.userInfo[NSURLSessionDownloadTaskResumeData];
    }
    
    [task onDownloader:self didCompleteWithError:error];
}

- (void) URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    PI_INFO_LOG(@"Got download finish");
    PiDownloadTask *task = [_storage findTaskWithId:downloadTask.taskIdentifier];
    if (task == nil)
    {
        [downloadTask cancel];
        return;
    }
    
    PI_INFO_LOG(@"Task finish with url : %@", task.downloadURL);
    [task onDownloader:self didFinishToURL:location];
    [_storage removeTask:task];
}

- (void) URLSession:(NSURLSession *)session
       downloadTask:(NSURLSessionDownloadTask *)downloadTask
       didWriteData:(int64_t)bytesWritten
  totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    PiDownloadTask *task = [_storage findTaskWithId:downloadTask.taskIdentifier];
    if (task == nil)
    {
        [downloadTask cancel];
        return;
    }
    [task onDownloader:self didWriteData:bytesWritten totalWritten:totalBytesWritten totalExpected:totalBytesExpectedToWrite];
}

- (void) URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session
{
    PI_INFO_LOG(@"DidFinishEventsForBackgroundURLSession");
    if (_bgCompletionHandler != nil)
    {
        _bgCompletionHandler();
    }
    _bgCompletionHandler = nil;
}

// MARK: - Reachability
#ifdef PIDOWNLOAD_IOS
- (void) stopAllTaskForNoNetwork
{
    _waitNetworkTaskList = [NSMutableArray array];
    NSArray *array = _storage.tasks.copy;
    for (PiDownloadTask *task in array)
    {
        if (task.state == PiDownloadTaskState_Running)
        {
            [_waitNetworkTaskList addObject:task];
            [task suspend];
        }
    }
}

- (void) resumeAllTaskForNetwork
{
    for (PiDownloadTask *task in _waitNetworkTaskList)
    {
        if (task.state == PiDownloadTaskState_Suspend) // 等待网络恢复过程中状态可能发送变化，例如取消下载，例如蜂窝手动下载
        {
            [task resume];
        }
    }
    _waitNetworkTaskList = nil;
}

- (void) reachabilityChange:(NSNotification *)notification
{
    Reachability *reach = [notification object];
    if ([reach isKindOfClass:[Reachability class]])
    {
        NetworkStatus status = [reach currentReachabilityStatus];
        switch (status) {
            case NotReachable: [self stopAllTaskForNoNetwork]; break;
            case ReachableViaWiFi: [self resumeAllTaskForNetwork]; break;
            case ReachableViaWWAN:
            {
                if (_config.autoStopOnWWAN)
                {
                    [self stopAllTaskForNoNetwork];
                }
                break;
            }
        }
    }
}

- (void) watchNetwork
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachabilityChange:)
                                                 name:kReachabilityChangedNotification
                                               object:nil];
}
#endif
@end
