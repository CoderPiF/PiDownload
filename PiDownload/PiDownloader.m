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

#if TARGET_OS_IPHONE
#import "Reachability.h"
#endif

@implementation PiDownloadConfig
- (instancetype) init
{
    self = [super init];
    if (self)
    {
        _autoStartOnLaunch = YES;
        _autoStopOnWWAN = YES;
        _autoSaveResumeSize = 0;
        _maxDownloadCount = 1;
        _autoStartNextTask = YES;
    }
    return self;
}

#define kClassVersion           @"ClassVersion"
#define kAutoSaveResumeSizeKey  @"AutoSaveResumeSizeKey"
#define kAutoStopOnWWAN         @"AutoStopOnWWAN"
#define kAutoStartOnLaunch      @"AutoStartOnLaunch"
#define kMaxDownloadCount       @"MaxDownloadCount"
#define kAutoStartNextTask      @"AutoStartNextTask"
+ (NSInteger) version
{
    return 1;
}

- (instancetype) initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self)
    {
        self.autoSaveResumeSize = [aDecoder decodeInt64ForKey:kAutoSaveResumeSizeKey];
        self.autoStopOnWWAN = [aDecoder decodeBoolForKey:kAutoStopOnWWAN];
        self.autoStartOnLaunch = [aDecoder decodeBoolForKey:kAutoStartOnLaunch];
        self.maxDownloadCount = [aDecoder decodeIntegerForKey:kMaxDownloadCount];
        self.autoStartNextTask = [aDecoder decodeBoolForKey:kAutoStartNextTask];
    }
    return self;
}

- (void) encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInteger:self.class.version forKey:kClassVersion];
    [aCoder encodeBool:self.autoStartOnLaunch forKey:kAutoStartOnLaunch];
    [aCoder encodeBool:self.autoStopOnWWAN forKey:kAutoStopOnWWAN];
    [aCoder encodeInt64:self.autoSaveResumeSize forKey:kAutoSaveResumeSizeKey];
    [aCoder encodeInteger:self.maxDownloadCount forKey:kMaxDownloadCount];
    [aCoder encodeBool:self.autoStartNextTask forKey:kAutoStartNextTask];
}

@end

@interface PiDownloader ()<NSURLSessionDownloadDelegate, PiDownloadTaskCreator>
#if TARGET_OS_IPHONE
@property (nonatomic, strong) NSMutableArray *waitNetworkTaskList;
@property (nonatomic, assign) NetworkStatus networkStatus;
#endif
@property (nonatomic, strong) PiDownloadTaskController *taskController;
@property (nonatomic, strong) PiDownloadStorage *storage;
@property (nonatomic, strong) NSURLSession *backgroundSession;
@end

@interface PiDownloader (Manager_Imp)
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

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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
        _taskController = [PiDownloadTaskController new];
        self.config = config;
        PI_INFO_LOG(@"Init Downloader With Identifier : %@", identifier);
        [self initBgSession];
        _storage = [PiDownloadStorage storageWithIdentifier:_sessionIdentifier];
        _taskController.storage = _storage;
        [self readyTaskList];
#if TARGET_OS_IPHONE
        [self watchNetwork];
#endif
    }
    
    [self.class AddDownloader:self];
    return self;
}

- (void) initBgSession
{
    assert(_backgroundSession == nil);
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:_sessionIdentifier];
    _backgroundSession = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:[NSOperationQueue mainQueue]];
}

// MARK: - Config
- (void) setConfig:(PiDownloadConfig *)config
{
    _config = config;
    [PiDownloadStorage saveConfig:_config forIdentifier:_sessionIdentifier];
    
    _taskController.autoStartNextTask = _config.autoStartNextTask;
    _taskController.maxDownloadCount = _config.maxDownloadCount;
#if TARGET_OS_IPHONE
    if (_networkStatus == ReachableViaWWAN && !_config.autoStopOnWWAN)
    {
        [self resumeAllTaskForNetwork];
    }
#endif
    
    for (PiDownloadTask *task in _storage.tasks)
    {
        task.autoSaveResumeSize = config.autoSaveResumeSize;
    }
}

// MARK: - Task
- (void) configTask:(PiDownloadTask *)task
{
    task.controller = _taskController;
    task.taskCreator = self;
    task.autoSaveResumeSize = _config.autoSaveResumeSize;
}

- (PiDownloadTask *) addTaskWithUrl:(NSString *)urlString
{
    PiDownloadTask *task = [_storage addTaskWithUrl:urlString];
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
        
        if (task.state == PiDownloadTaskState_Running || task.state == PiDownloadTaskState_Waiting)
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
    dispatch_sync(dispatch_get_main_queue(), ^{
        if (_bgCompletionHandler != nil)
        {
            _bgCompletionHandler();
        }
        _bgCompletionHandler = nil;
    });
}

// MARK: - Reachability
#if TARGET_OS_IPHONE
- (void) stopAllTaskForNoNetwork
{
    _taskController.disableAutoStart = YES;
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
    _taskController.disableAutoStart = NO;
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
        _networkStatus = [reach currentReachabilityStatus];
        switch (_networkStatus) {
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


// MARK: - Manager
@implementation PiDownloader (Manager)
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
