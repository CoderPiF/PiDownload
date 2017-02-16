//
//  PiDownloader.m
//  PiDownload
//
//  Created by 江派锋 on 2017/2/16.
//  Copyright © 2017年 Coder.Pi. All rights reserved.
//

#import "PiDownloader.h"
#import "PiDownloadLogger.h"

// MARK: - DownloadTask
@interface PiDownloadTask (Downloader)
@property (nonatomic) NSData *resumeData;
@property (nonatomic) NSURLSessionDownloadTask *task;

- (BOOL) isValidresumeData;
- (void) onDownloader:(PiDownloader *)downloader didCompleteWithError:(NSError *)error;
- (void) onDownloader:(PiDownloader *)downloader didFinishToURL:(NSURL *)location;
- (void) onDownloader:(PiDownloader *)downloader didWriteData:(int64_t)bytesWritten totalWritten:(int64_t)totalWritten totalExpected:(int64_t)totalExpected;
@end

// MARK: - Impl
@interface PiDownloader ()<NSURLSessionDownloadDelegate>
{
    NSMutableArray<PiDownloadTask *> *_tasks;
}
@property (nonatomic, strong) NSURLSession *backgroundSession;
@end

@implementation PiDownloader

// MARK: - Init
+ (PiDownloader *) SharedObject
{
    static PiDownloader *s_shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *defaultIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        defaultIdentifier = [defaultIdentifier stringByAppendingString:@".PiDownloader"];
        s_shared = [[PiDownloader alloc] initWithIdentifier:defaultIdentifier];
    });
    return s_shared;
}

- (instancetype) initWithIdentifier:(NSString *)identifier
{
    self = [super init];
    if (self)
    {
        PI_INFO_LOG(@"Init Downloader With Identifier : %@", identifier);
        _identifier = identifier;
        _tasks = [NSMutableArray array];
        [self initBgSession];
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
- (PiDownloadTask *) findTaskWithIdentifier:(NSUInteger)taskIdentifier
{
    for (PiDownloadTask *task in _tasks)
    {
        if (task.identifier == taskIdentifier)
        {
            return task;
        }
    }
    PI_WARNING_LOG(@"Can not found task with Identifier : %lu", (unsigned long)taskIdentifier);
    return nil;
}

- (PiDownloadTask *) findTaskWithUrlString:(NSString *)urlString
{
    for (PiDownloadTask *task in _tasks)
    {
        if ([task.downloadURL caseInsensitiveCompare:urlString] == NSOrderedSame)
        {
            return task;
        }
    }
    return nil;
}

- (void) createDownloadTask:(PiDownloadTask *)task
{
    if (task.task != nil) return;
    
    if ([task isValidresumeData])
    {
        task.task = [_backgroundSession downloadTaskWithResumeData:task.resumeData];
    }
    else
    {
        task.task = [_backgroundSession downloadTaskWithURL:[NSURL URLWithString:task.downloadURL]];
    }
}

- (PiDownloadTask *) addTaskWithUrl:(NSString *)urlString
{
    PiDownloadTask *task = [self findTaskWithUrlString:urlString];
    if (task != nil)
    {
        return task;
    }
    
    task = [PiDownloadTask taskWithURL:urlString];
    [self createDownloadTask:task];
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
    [_tasks removeObject:task];
    return YES;
}

- (BOOL) removeTaskWithUrl:(NSString *)urlString
{
    PiDownloadTask *task = [self findTaskWithUrlString:urlString];
    return [self removeTask:task];
}

// MARK: - NSURLSessionDownloadDelegate
- (void) URLSession:(NSURLSession *)session task:(NSURLSessionTask *)downloadTask didCompleteWithError:(NSError *)error
{
    if (error == nil) return;
    
    PI_INFO_LOG(@"Got download error");
    PiDownloadTask *task = [self findTaskWithIdentifier:downloadTask.taskIdentifier];
    if (task == nil) return;
    
    if (error.code == NSURLErrorCancelled)
    {
        task.resumeData = nil;
        [_tasks removeObject:task];
        PI_INFO_LOG(@"Cancel Download Task with URL : %@", task.downloadURL);
    }
    else
    {
        task.resumeData = error.userInfo[NSURLSessionDownloadTaskResumeData];
    }
    
    [task onDownloader:self didCompleteWithError:error];
    task.task = nil; // FIXME: 发生错误时：task标记错误，状态改变为重新开始时，需要在downloader重新创建downloadTask
}

- (void) URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    PI_INFO_LOG(@"Got download finish");
    PiDownloadTask *task = [self findTaskWithIdentifier:downloadTask.taskIdentifier];
    if (task == nil) return;
    
    PI_INFO_LOG(@"Task finish with url : %@", task.downloadURL);
    task.resumeData = nil;
    [task onDownloader:self didFinishToURL:location];
    [_tasks removeObject:task];
}

- (void) URLSession:(NSURLSession *)session
       downloadTask:(NSURLSessionDownloadTask *)downloadTask
       didWriteData:(int64_t)bytesWritten
  totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    PiDownloadTask *task = [self findTaskWithIdentifier:downloadTask.taskIdentifier];
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
