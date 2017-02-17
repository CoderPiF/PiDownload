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

@interface PiDownloader ()<NSURLSessionDownloadDelegate, PiDownloadTaskCreator>
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
        task.resumeData = nil;
        [_storage removeTask:task];
        PI_INFO_LOG(@"Cancel Download Task with URL : %@", task.downloadURL);
    }
    else
    {
        task.resumeData = error.userInfo[NSURLSessionDownloadTaskResumeData];
        [_storage saveTaskList];
    }
    
    [task onDownloader:self didCompleteWithError:error];
}

- (void) URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    PI_INFO_LOG(@"Got download finish");
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

@end
