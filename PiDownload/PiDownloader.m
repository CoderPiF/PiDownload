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
#import "PiDownloadTaskController.h"

@interface PiDownloader ()<NSURLSessionDownloadDelegate, PiDownloadTaskCreator>
@property (nonatomic, strong) PiDownloadTaskController *controller;
@property (nonatomic, strong) PiDownloadStorage *storage;
@property (nonatomic, strong) NSURLSession *backgroundSession;

+ (void) AddDownloader:(PiDownloader *)downloader;
@end

@implementation PiDownloader

// MARK: - Init
+ (NSString *) DefaultIdentifier
{
    return [NSString stringWithFormat:@"%@.PiDownload", [[NSBundle mainBundle] bundleIdentifier]];
}

+ (NSString *) SessionIdentifier:(NSString *)identifier
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

+ (PiDownloader *) downloaderWithIdentifier:(NSString *)identifier config:(PiDownloadConfig *)config
{
    NSString *sessionIdentifier = [self SessionIdentifier:identifier];
    PiDownloader *downloader = [self DownloaderWithSessionIdentifier:sessionIdentifier];
    if (downloader != nil)
    {
        return downloader;
    }
    
    return [[self alloc] initWithIdentifier:identifier config:config];
}

- (instancetype) initWithIdentifier:(NSString *)identifier
{
    NSString *tmpId = [self.class SessionIdentifier:identifier];
    PiDownloadConfig *config = [PiDownloadStorage readLastConfigWithIdentifier:tmpId];
    return [self initWithIdentifier:identifier config:config];
}

- (instancetype) initWithIdentifier:(NSString *)identifier config:(PiDownloadConfig *)config
{
    self = [super init];
    if (self)
    {
        _identifier = identifier;
        _sessionIdentifier = [self.class SessionIdentifier:identifier];
        _controller = [PiDownloadTaskController new];
        self.config = config;
        PI_INFO_LOG(@"Init Downloader With Identifier : %@", identifier);
        [self initBgSession];
        _storage = [PiDownloadStorage storageWithIdentifier:_sessionIdentifier];
        _controller.storage = _storage;
        [self readyTaskList];
    }
    
    [self.class AddDownloader:self];
    return self;
}

- (void) initBgSession
{
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:_sessionIdentifier];
    _backgroundSession = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:[NSOperationQueue mainQueue]];
}

// MARK: - Config
- (void) setConfig:(PiDownloadConfig *)config
{
    _config = config;
    [PiDownloadStorage saveConfig:_config forIdentifier:_sessionIdentifier];
    
    _controller.autoStartNextTask = _config.autoStartNextTask;
    _controller.maxDownloadCount = _config.maxDownloadCount;
    _controller.autoStopOnWWAN = _config.autoStopOnWWAN;

    for (PiDownloadTask *task in _storage.tasks)
    {
        task.autoSaveResumeSize = config.autoSaveResumeSize;
    }
}

// MARK: - Task
- (void) configTask:(PiDownloadTask *)task
{
    task.controller = _controller;
    task.taskCreator = self;
    task.autoSaveResumeSize = _config.autoSaveResumeSize;
}

- (PiDownloadTask *) addTaskWithUrl:(NSString *)urlString toLocalPath:(NSString *)localPath
{
    PiDownloadTask *task = [_storage addTaskWithUrl:urlString];
    [task addLocalPath:localPath];
    [self configTask:task];
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
        [self configTask:task];
        [task ready];
        
        if (task.state == PiDownloadTaskState_Waiting)
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

// MARK: - NSURLSessionDelegate
- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(NSError *)error
{
    if (session == _backgroundSession)
    {
        [self initBgSession];
    }
}

// MARK: - NSURLSessionDownloadDelegate
- (void) URLSession:(NSURLSession *)session task:(NSURLSessionTask *)downloadTask didCompleteWithError:(NSError *)error
{
    if (error == nil) return;
    
    PiDownloadTask *task = [_storage findTaskWithId:downloadTask.taskIdentifier];
    if (task == nil) return;
    
    PI_INFO_LOG(@"Got download error");
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
        NSData *data = error.userInfo[NSURLSessionDownloadTaskResumeData];
        if ([PiDownloadStorage isValidresumeData:data])
        {
            task.resumeData = data;
        }
    }
    
    [task onDownloader:self didCompleteWithError:error];
}

- (void) URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    PiDownloadTask *task = [_storage findTaskWithId:downloadTask.taskIdentifier];
    if (task == nil) return;
    
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
        BgDownloadCompletionHandler handler = _bgCompletionHandler;
        _bgCompletionHandler = nil;
        dispatch_sync(dispatch_get_main_queue(), ^{
            handler();
        });
    }
}

// MARK: - Manager
+ (NSMutableArray<PiDownloader *> *) Downloaders
{
    static NSMutableArray *s_list = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_list = [NSMutableArray array];
    });
    return s_list;
}

+ (void) AddDownloader:(PiDownloader *)downloader
{
    if ([self DownloaderWithSessionIdentifier:downloader.sessionIdentifier] == nil)
    {
        [self.Downloaders addObject:downloader];
    }
}

+ (BOOL) IsPiDownloaderSessionIdentifier:(NSString *)sessionIdentifier
{
    return [sessionIdentifier hasPrefix:self.DefaultIdentifier];
}

+ (PiDownloader *) DownloaderWithSessionIdentifier:(NSString *)sessionIdentifier
{
    if (![self IsPiDownloaderSessionIdentifier:sessionIdentifier]) return nil;
    
    for (PiDownloader *downloader in self.Downloaders)
    {
        if ([downloader.sessionIdentifier isEqualToString:sessionIdentifier])
        {
            return downloader;
        }
    }
    return nil;
}

+ (PiDownloader *) CreateDownloaderWithSessionIdentifier:(NSString *)sessionIdentifier
{
    if (![self IsPiDownloaderSessionIdentifier:sessionIdentifier]) return nil;
    
    NSString *defaultId = [NSString stringWithFormat:@"%@.", self.DefaultIdentifier];
    NSString *identifier = [sessionIdentifier stringByReplacingOccurrencesOfString:defaultId withString:@""];
    return [[self alloc] initWithIdentifier:identifier];
}
@end
