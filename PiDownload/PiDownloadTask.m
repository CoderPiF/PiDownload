//
//  PiDownloadTask.m
//  PiDownload
//
//  Created by 江派锋 on 2017/2/16.
//  Copyright © 2017年 Coder.Pi. All rights reserved.
//

#import "PiDownloadTask.h"
#import "PiDownloader.h"

@interface PiDownloadTask ()
{
    NSTimeInterval _runningTime;
    NSTimeInterval _lastRunningTime;
}
@property (nonatomic, strong) NSURLSessionDownloadTask *task;
@property (nonatomic, strong) NSData *resumeData;
@end

@implementation PiDownloadTask

// MARK: - Init
+ (PiDownloadTask *) taskWithURL:(NSString *)url
{
    return [[self alloc] initWithURL:url];
}

- (instancetype) initWithURL:(NSString *)url
{
    self = [super init];
    if (self)
    {
        _downloadURL = url;
    }
    return self;
}

// MARK: - task
#define kTaskStateKeyPath @"state"
- (void) dealloc
{
    [_task removeObserver:self forKeyPath:kTaskStateKeyPath];
}

- (void) setTask:(NSURLSessionDownloadTask *)task
{
    if (_task == task) return;
    
    if (_task != nil)
    {
        [_task removeObserver:self forKeyPath:kTaskStateKeyPath];
    }
    _task = task;
    [_task addObserver:self forKeyPath:kTaskStateKeyPath options:NSKeyValueObservingOptionNew context:nil];
    _runningTime = 0;
    _lastRunningTime = 0;
    if (_task.state == NSURLSessionTaskStateRunning)
    {
        [self recordRunningTime];
    }
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if (object == _task && [keyPath isEqualToString:kTaskStateKeyPath])
    {
        NSURLSessionTaskState state = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
        if (state == NSURLSessionTaskStateRunning)
        {
            [self recordRunningTime];
        }
        else
        {
            [self updateRunningTime];
        }
    }
}

// MARK: - ResumeData
+ (BOOL) isValidresumeData:(NSData *)resumeData
{
    if (resumeData.length == 0) return NO;
    NSError *error;
    id resumeDictionary = [NSPropertyListSerialization propertyListWithData:resumeData options:NSPropertyListImmutable format:nil error:&error];
    if (resumeDictionary == nil || error != nil) return NO;
    
    NSString *localFilePath = resumeDictionary[@"NSURLSessionResumeInfoLocalPath"];
    if (localFilePath.length < 1)
    {
        localFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:resumeDictionary[@"NSURLSessionResumeInfoTempFileName"]];
    }
    
    if (localFilePath.length < 1) return NO;
    
    return [[NSFileManager defaultManager] fileExistsAtPath:localFilePath];
}

- (BOOL) isValidresumeData
{
    return [PiDownloadTask isValidresumeData:_resumeData];
}

- (void) setResumeData:(NSData *)resumeData
{
    if (_resumeData == resumeData) return;
    if (![PiDownloadTask isValidresumeData:resumeData]) return;
    
    _resumeData = resumeData;
}

// MARK: - Running Time
- (void) recordRunningTime
{
    [self updateRunningTime];
    _lastRunningTime = [[NSDate date] timeIntervalSince1970];
}

- (void) updateRunningTime
{
    if (_lastRunningTime > 0)
    {
        _runningTime += [[NSDate date] timeIntervalSince1970] - _lastRunningTime;
    }
    _lastRunningTime = 0;
}

- (NSTimeInterval) runningTime
{
    if (_lastRunningTime > 0)
    {
        return _runningTime + [[NSDate date] timeIntervalSince1970] - _lastRunningTime;
    }
    return _runningTime;
}

// MARK: - Transmission
- (NSUInteger) identifier
{
    return _task.taskIdentifier;
}

- (PiDownloadTaskState) state
{
    return (PiDownloadTaskState)_task.state;
}

- (int64_t) totalSize
{
    return _task.countOfBytesExpectedToReceive;
}

- (int64_t) receivedSize
{
    return _task.countOfBytesReceived;
}

- (float) progress
{
    return (float)self.receivedSize / (float)self.totalSize;
}

- (float) speed
{
    return (float)self.receivedSize / (float)self.runningTime;
}

- (NSTimeInterval) estimationTime
{
    return (NSTimeInterval) (self.totalSize - self.receivedSize) / self.speed;
}

- (void) resume
{
    [_task resume];
}

- (void) suspend
{
    [_task suspend];
}

- (void) cancel
{
    [_task cancel];
}

// MARK: - Downloader
- (void) onDownloader:(PiDownloader *)downloader didCompleteWithError:(NSError *)error
{
    if ([_delegate respondsToSelector:@selector(onPiDownloadTask:downloadError:)])
    {
        [_delegate onPiDownloadTask:self downloadError:error];
    }
}

- (void) onDownloader:(PiDownloader *)downloader didFinishToURL:(NSURL *)location
{
    if ([_delegate respondsToSelector:@selector(onPiDownloadTask:didFinishDownloadToFile:)])
    {
        [_delegate onPiDownloadTask:self didFinishDownloadToFile:location];
    }
}

- (void) onDownloader:(PiDownloader *)downloader didWriteData:(int64_t)bytesWritten totalWritten:(int64_t)totalWritten totalExpected:(int64_t)totalExpected
{
    if ([_delegate respondsToSelector:@selector(onPiDownloadTask:didUpdateProgress:)])
    {
        [_delegate onPiDownloadTask:self didUpdateProgress:self.progress];
    }
}

@end
