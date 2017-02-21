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
#import "PiDownloadStorage.h"
#import "PiDownloadTaskController.h"

@interface PiDownloadTask ()
{
    NSTimeInterval _lastRunningTime;
    
    int64_t _totalSize;
    int64_t _receivedSize;
    
    int64_t _lastSaveResumeSize;
}
@property (nonatomic, strong) NSMutableArray *localPaths;
@property (nonatomic, assign) int64_t autoSaveResumeSize;
@property (nonatomic, assign) NSTimeInterval runningTime;
@property (nonatomic, strong) NSURLSessionDownloadTask *task;

@property (nonatomic, weak) PiDownloadTaskController *controller;
@property (nonatomic, weak) id<PiDownloadTaskCreator> taskCreator;
@property (nonatomic, weak) id<PiDownloadTaskStorage> storage;
@end

@implementation PiDownloadTask

+ (NSInteger) version
{
    return 1;
}

// MARK: - NSCoding
#define kClassVersionKey        @"ClassVersion"
#define kDownloadURLKey         @"DownloadUrl"
#define kDownloadStateKey       @"DownloadState"
#define kRunningTimeKey         @"RunningTime"
#define kTotalSizeKey           @"TotalSize"
#define kReceivedSizeKey        @"ReceivedSize"
#define kLastSaveResumeSizeKey  @"LastSaveResumeSize"
#define kLocalPathsKey          @"LocalPaths"
#define kUserDataKey            @"UserData"
- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInteger:self.class.version forKey:kClassVersionKey];
    [aCoder encodeObject:self.downloadURL forKey:kDownloadURLKey];
    PiDownloadTaskState state = (self.state == PiDownloadTaskState_Running) ? PiDownloadTaskState_Waiting : self.state;
    [aCoder encodeInteger:state forKey:kDownloadStateKey];
    [aCoder encodeDouble:self.runningTime forKey:kRunningTimeKey];
    [aCoder encodeInt64:self.totalSize forKey:kTotalSizeKey];
    [aCoder encodeInt64:self.receivedSize forKey:kReceivedSizeKey];
    [aCoder encodeInt64:_lastSaveResumeSize forKey:kLastSaveResumeSizeKey];
    [aCoder encodeObject:self.localPaths forKey:kLocalPathsKey];
    [aCoder encodeObject:self.userData forKey:kUserDataKey];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self)
    {
        _downloadURL = [aDecoder decodeObjectForKey:kDownloadURLKey];
        _state = [aDecoder decodeIntegerForKey:kDownloadStateKey];
        _runningTime = [aDecoder decodeDoubleForKey:kRunningTimeKey];
        _totalSize = [aDecoder decodeInt64ForKey:kTotalSizeKey];
        _receivedSize = [aDecoder decodeInt64ForKey:kReceivedSizeKey];
        _userData = [aDecoder decodeObjectForKey:kUserDataKey];
        _localPaths = ((NSArray *)[aDecoder decodeObjectForKey:kLocalPathsKey]).mutableCopy;
        _lastSaveResumeSize = [aDecoder decodeInt64ForKey:kLastSaveResumeSizeKey];
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
        _localPaths = [NSMutableArray array];
        _state = PiDownloadTaskState_Waiting;
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

// MARK: - LocalPaths
- (void) addLocalPath:(NSString *)localPath
{
    for (NSString *path in _localPaths)
    {
        if ([path isEqualToString:localPath])
        {
            return;
        }
    }
    [_localPaths addObject:localPath];
}

- (void) saveToLocalPaths:(NSURL *)fileUrl
{
    NSFileManager *manager = [NSFileManager defaultManager];
    for (NSString *path in _localPaths)
    {
        [manager copyItemAtURL:fileUrl toURL:[NSURL fileURLWithPath:path] error:nil];
    }
}

// MARK: - ResumeData
- (BOOL) isValidresumeData
{
    return [PiDownloadStorage isValidresumeData:self.resumeData];
}

- (void) setResumeData:(NSData *)resumeData
{
    if ([_storage respondsToSelector:@selector(onPiDownloadTask:saveResumeData:)])
    {
        [_storage onPiDownloadTask:self saveResumeData:resumeData];
    }
}

- (NSData *) resumeData
{
    if ([_storage respondsToSelector:@selector(onPiDownloadTaskReadResumeData:)])
    {
        return [_storage onPiDownloadTaskReadResumeData:self];
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
    if (self.totalSize < 1) return 0;
    return (float)self.receivedSize / (float)self.totalSize;
}

- (float) speed
{
    if (self.runningTime < 1) return 0;
    return (float)self.receivedSize / (float)self.runningTime;
}

- (NSTimeInterval) estimationTime
{
    if (self.speed < 1) return 0;
    return (NSTimeInterval) (self.totalSize - self.receivedSize) / self.speed;
}

- (void) ready
{
    if (_task != nil) return;
    if ([_taskCreator respondsToSelector:@selector(onDownloadTaskCreate:)])
    {
        self.task = [_taskCreator onDownloadTaskCreate:self];
    }
}

- (void) setState:(PiDownloadTaskState)state
{
    if (_state == state) return;
    if (_state == PiDownloadTaskState_Running)
    {
        _state = state;
        [_controller onTaskStopRunning:self];
    }
    
    _state = state;
    if ([_delegate respondsToSelector:@selector(onPiDownloadTask:didStateChange:)])
    {
        [_delegate onPiDownloadTask:self didStateChange:state];
    }
}

- (void) resume
{
    if (self.state == PiDownloadTaskState_Running) return;
    
    if (!_controller.canStartTask)
    {
        self.state = PiDownloadTaskState_Waiting;
        return;
    }
    
    self.state = PiDownloadTaskState_Running;
    [self startTask];
}

- (void) startTask
{
    [self ready];
    [_task resume];
}

- (void) suspend
{
    self.state = PiDownloadTaskState_Suspend;
    [_task cancelByProducingResumeData:^(NSData *resumeData) {
        if ([PiDownloadStorage isValidresumeData:resumeData])
        {
            self.resumeData = resumeData;
        }
    }];
    self.task = nil;
}

- (void) cancel
{
    self.state = PiDownloadTaskState_Canceling;
    [_task cancel];
    self.task = nil;
    if ([_storage respondsToSelector:@selector(onPiDownloadRemove:)])
    {
        [_storage onPiDownloadRemove:self];
    }
}

// MARK: - Downloader
- (void) onDownloader:(PiDownloader *)downloader didCompleteWithError:(NSError *)error
{
    self.task = nil;
    if (self.state == PiDownloadTaskState_Canceling) return;
    
    self.state = PiDownloadTaskState_Error;
    if ([_delegate respondsToSelector:@selector(onPiDownloadTask:downloadError:)])
    {
        [_delegate onPiDownloadTask:self downloadError:error];
    }
}

- (void) onDownloader:(PiDownloader *)downloader didFinishToURL:(NSURL *)location
{
    [self saveToLocalPaths:location];
    
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
    
    if (_autoSaveResumeSize > 0 && totalWritten - _lastSaveResumeSize > _autoSaveResumeSize)
    {
        [_task cancelByProducingResumeData:^(NSData *resumeData) {
            if ([PiDownloadStorage isValidresumeData:resumeData])
            {
                self.resumeData = resumeData;
                _lastSaveResumeSize = totalWritten;
            }
            [self startTask];
        }];
        self.task = nil;
    }
}

@end
