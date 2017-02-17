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

@interface PiDownloadTask ()
{
    NSTimeInterval _lastRunningTime;
    
    int64_t _totalSize;
    int64_t _receivedSize;
}
@property (nonatomic, strong) NSData *resumeData;
@property (nonatomic, assign) NSTimeInterval runningTime;
@property (nonatomic, strong) NSURLSessionDownloadTask *task;

@property (nonatomic, weak) id<PiDownloadTaskCreator> taskCreator;
@end

@implementation PiDownloadTask

// MARK: - NSCoding
#define kDownloadURLKey     @"DownloadUrl"
#define kResumeDataKey      @"ResumeData"
#define kRunningTimeKey     @"RunningTime"
#define kTotalSizeKey       @"TotalSize"
#define kReceivedSizeKey    @"ReceivedSize"
#define kUserDataKey        @"UserData"
- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.downloadURL forKey:kDownloadURLKey];
    [aCoder encodeObject:self.resumeData forKey:kResumeDataKey];
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
        _resumeData = [aDecoder decodeObjectForKey:kResumeDataKey];
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
    return [PiDownloadTask isValidresumeData:self.resumeData];
}

- (void) setResumeData:(NSData *)resumeData
{
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
    if (_task == nil) return PiDownloadTaskState_Error;
    return (PiDownloadTaskState)_task.state;
}

- (int64_t) totalSize
{
    if (_task == nil) return _totalSize;
    return _task.countOfBytesExpectedToReceive;
}

- (int64_t) receivedSize
{
    if (_task == nil) return _receivedSize;
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

- (void) ready
{
    if (_task != nil) return;
    if ([_taskCreator respondsToSelector:@selector(onDownloadTaskCreate:)])
    {
        self.task = [_taskCreator onDownloadTaskCreate:self];
    }
}

- (void) resume
{
    [self ready];
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
    self.task = nil;
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
