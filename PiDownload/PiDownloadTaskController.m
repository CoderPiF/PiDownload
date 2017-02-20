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

@implementation PiDownloadTaskController
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

@end
