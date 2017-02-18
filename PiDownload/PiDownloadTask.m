//
//  PiDownloadTask.m
//  PiDownload
//
//  Created by 江派锋 on 2017/2/16.
//  Copyright © 2017年 Coder.Pi. All rights reserved.
//

#import "PiDownloadTask.h"
#import "PiDownloader.h"
#import "PiDownloadTaskImp.h"
#import "PiDownloadLogger.h"

@interface PiDownloadTask ()
{
    NSTimeInterval _lastRunningTime;
    
    int64_t _totalSize;
    int64_t _receivedSize;
}
@property (nonatomic, assign) NSTimeInterval runningTime;
@property (nonatomic, strong) NSURLSessionDownloadTask *task;

@property (nonatomic, weak) id<PiDownloadTaskCreator> taskCreator;
@property (nonatomic, weak) id<PiDownloadTaskResumeData> resumeDataStorage;
@end

@implementation PiDownloadTask

// MARK: - NSCoding
#define kDownloadURLKey         @"DownloadUrl"
#define kDownloadStateKey       @"DownloadState"
#define kRunningTimeKey         @"RunningTime"
#define kTotalSizeKey           @"TotalSize"
#define kReceivedSizeKey        @"ReceivedSize"
#define kUserDataKey            @"UserData"
- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.downloadURL forKey:kDownloadURLKey];
    [aCoder encodeObject:@(self.state) forKey:kDownloadStateKey];
    [aCoder encodeObject:@(self.runningTime) forKey:kRunningTimeKey];
    [aCoder encodeObject:@(self.totalSize) forKey:kTotalSizeKey];
    [aCoder encodeObject:@(self.receivedSize) forKey:kReceivedSizeKey];
    [aCoder encodeObject:self.userData forKey:kUserDataKey];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self)
    {
        _downloadURL = [aDecoder decodeObjectForKey:kDownloadURLKey];
        _state = [[aDecoder decodeObjectForKey:kDownloadStateKey] integerValue];
        _runningTime = [[aDecoder decodeObjectForKey:kRunningTimeKey] doubleValue];
        _totalSize = [[aDecoder decodeObjectForKey:kTotalSizeKey] longLongValue];
        _receivedSize = [[aDecoder decodeObjectForKey:kReceivedSizeKey] longLongValue];
        _userData = [aDecoder decodeObjectForKey:kUserDataKey];
    }
    return self;
}


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
    
    [_task removeObserver:self forKeyPath:kTaskStateKeyPath];
    if (task == nil)
    {
        _totalSize = self.totalSize;
        _receivedSize = self.receivedSize;
    }
    
    _task = task;
    _lastRunningTime = 0;
    if (_task != nil)
    {
        [_task addObserver:self forKeyPath:kTaskStateKeyPath options:NSKeyValueObservingOptionNew context:nil];
        if (_task.state == NSURLSessionTaskStateRunning)
        {
            [self recordRunningTime];
        }
    }
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if (object == _task && [keyPath isEqualToString:kTaskStateKeyPath])
    {
        NSURLSessionTaskState state = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.task != object) return;
            
            if (state == NSURLSessionTaskStateRunning)
            {
                [self recordRunningTime];
            }
            else
            {
                [self updateRunningTime];
            }
        });
    }
}

// MARK: - ResumeData
+ (BOOL) isValidresumeData:(NSData *)resumeData
{
    if (resumeData == nil) return NO;
    
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
    return [PiDownloadTask isValidresumeData:self.resumeData];
}

- (void) setResumeData:(NSData *)resumeData
{
    if ([_resumeDataStorage respondsToSelector:@selector(onPidDownloadTask:saveResumeData:)])
    {
        [_resumeDataStorage onPidDownloadTask:self saveResumeData:resumeData];
    }
}

- (NSData *) resumeData
{
    if ([_resumeDataStorage respondsToSelector:@selector(onPiDownloadTaskReadResumeData:)])
    {
        return [_resumeDataStorage onPiDownloadTaskReadResumeData:self];
    }
    return nil;
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

- (int64_t) totalSize
{
    return (_task.countOfBytesExpectedToReceive > 0) ? _task.countOfBytesExpectedToReceive : _totalSize;
}

- (int64_t) receivedSize
{
    return (_task.countOfBytesReceived > 0) ? _task.countOfBytesReceived : _receivedSize;
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

- (void) ready
{
    if (_task != nil) return;
    if ([_taskCreator respondsToSelector:@selector(onDownloadTaskCreate:)])
    {
        self.task = [_taskCreator onDownloadTaskCreate:self];
        self.resumeData = nil;
    }
}

- (void) setState:(PiDownloadTaskState)state
{
    if (_state == state) return;
    
    _state = state;
    if ([_delegate respondsToSelector:@selector(onPiDownloadTask:didStateChange:)])
    {
        [_delegate onPiDownloadTask:self didStateChange:state];
    }
}

- (void) resume
{
    [self ready];
    self.state = PiDownloadTaskState_Running;
    [_task resume];
}

- (void) stopAndSaveResumeData
{
    [_task cancelByProducingResumeData:^(NSData *resumeData) {
        self.resumeData = resumeData;
    }];
}

- (void) suspend
{
    self.state = PiDownloadTaskState_Suspend;
    [self stopAndSaveResumeData];
}

- (void) cancel
{
    self.state = PiDownloadTaskState_Canceling;
    [_task cancel];
}

// MARK: - Downloader
- (void) onDownloader:(PiDownloader *)downloader didCompleteWithError:(NSError *)error
{
    self.task = nil;
    if (self.state != PiDownloadTaskState_Running)
    {
        return;
    }
    
    self.state = PiDownloadTaskState_Error;
    if ([_delegate respondsToSelector:@selector(onPiDownloadTask:downloadError:)])
    {
        [_delegate onPiDownloadTask:self downloadError:error];
    }
}

- (void) onDownloader:(PiDownloader *)downloader didFinishToURL:(NSURL *)location
{
    self.state = PiDownloadTaskState_Completed;
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
