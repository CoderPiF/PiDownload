//
//  PiDownloadTaskController.m
//  PiDownload
//
//  Created by 江派锋 on 2017/2/20.
//  Copyright © 2017年 Coder.Pi. All rights reserved.
//

#import "PiDownloadTaskController.h"
#import "PiDownloadStorage.h"
#import "PiDownloadTaskImp.h"
#import "Reachability.h"

@interface PiDownloadTaskController ()
@property (nonatomic, assign) BOOL disableAutoStart; // 蜂窝状态下并且打开蜂窝不下载的配置时：disable
@property (nonatomic, strong) NSMutableArray *waitNetworkTaskList;
@property (nonatomic, assign) NetworkStatus networkStatus;
@end

@implementation PiDownloadTaskController
- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype) init
{
    self = [super init];
    if (self)
    {
        [self watchNetwork];
    }
    return self;
}

- (void) checkAndStopTask
{
    NSUInteger downloadingCount = self.downloadingCount;
    if (downloadingCount <= self.maxDownloadCount) return;
    
    NSUInteger stopCount = downloadingCount - self.maxDownloadCount;
    for (PiDownloadTask *task in _storage.tasks)
    {
        if (task.state == PiDownloadTaskState_Running)
        {
            [task suspend];
            task.state = PiDownloadTaskState_Waiting;
            if (--stopCount == 0) return;
        }
    }
}

- (void) checkAndStartTask
{
    if (!self.canStartTask || !self.autoStartNextTask) return;
    
    for (PiDownloadTask *task in _storage.tasks)
    {
        if (task.state == PiDownloadTaskState_Waiting)
        {
            [task resume];
            return;
        }
    }
}

- (BOOL) autoStartNextTask
{
    return !_disableAutoStart && _autoStartNextTask;
}

- (void) setStorage:(PiDownloadStorage *)storage
{
    if (_storage == storage) return;
    _storage = storage;
    [self checkAndStopTask];
    [self checkAndStartTask];
}

- (void) setMaxDownloadCount:(NSUInteger)maxDownloadCount
{
    maxDownloadCount = MAX(1, maxDownloadCount);
    if (_maxDownloadCount > maxDownloadCount)
    {
        _maxDownloadCount = maxDownloadCount;
        [self checkAndStopTask];
    }
    _maxDownloadCount = maxDownloadCount;
}

- (void) setAutoStopOnWWAN:(BOOL)autoStopOnWWAN
{
    if (_autoStopOnWWAN == autoStopOnWWAN) return;
    _autoStopOnWWAN = autoStopOnWWAN;
    if (_networkStatus == ReachableViaWWAN && !_autoStopOnWWAN)
    {
        [self resumeAllTaskForNetwork];
    }
}

- (NSUInteger) downloadingCount
{
    NSUInteger count = 0;
    for (PiDownloadTask *task in _storage.tasks)
    {
        if (task.state == PiDownloadTaskState_Running) ++count;
    }
    return count;
}

- (BOOL) canStartTask
{
    return self.downloadingCount < self.maxDownloadCount;
}

- (void) onTaskStopRunning:(PiDownloadTask *)task
{
    [self checkAndStartTask];
}

// MARK: - Reachability
- (void) stopAllTaskForNoNetwork
{
    self.disableAutoStart = YES;
    _waitNetworkTaskList = [NSMutableArray array];
    NSArray *array = _storage.tasks.copy;
    for (PiDownloadTask *task in array)
    {
        if (task.state == PiDownloadTaskState_Running ||
            task.state == PiDownloadTaskState_Waiting)
        {
            [_waitNetworkTaskList addObject:task];
            [task suspend];
        }
    }
}

- (void) resumeAllTaskForNetwork
{
    self.disableAutoStart = NO;
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
                if (_autoStopOnWWAN)
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
@end
