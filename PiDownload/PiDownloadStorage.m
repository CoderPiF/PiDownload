//
//  PiDownloadStorage.m
//  PiDownload
//
//  Created by 江派锋 on 2017/2/16.
//  Copyright © 2017年 Coder.Pi. All rights reserved.
//

#import "PiDownloadStorage.h"
#import "PiDownloadLogger.h"
#import "PiDownloadTaskImp.h"

@interface PiDownloadStorage ()
{
    NSMutableArray<PiDownloadTask *> *_tasks;
    NSString *_taskListPath;
}
@end

@implementation PiDownloadStorage
+ (PiDownloadStorage *) storageWithIdentifier:(NSString *)identifier
{
    return [[PiDownloadStorage alloc] initWithIdentifier:identifier];
}

- (void) readTaskListWithIdentifier:(NSString *)identifier
{
    NSString *documentDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    _taskListPath = [documentDirectory stringByAppendingPathComponent:identifier];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:_taskListPath])
    {
        _tasks = ((NSArray *)[NSKeyedUnarchiver unarchiveObjectWithFile:_taskListPath]).mutableCopy;
    }
    
    if (_tasks == nil)
    {
        _tasks = [NSMutableArray array];
    }
}

- (void) saveTaskList
{
    if (![NSKeyedArchiver archiveRootObject:_tasks toFile:_taskListPath])
    {
        PI_ERROR_LOG(@"Save Task List Fail");
    }
}

- (instancetype) initWithIdentifier:(NSString *)identifier
{
    self = [super init];
    if (self)
    {
        [self readTaskListWithIdentifier:identifier];
    }
    return self;
}

- (PiDownloadTask *) findTaskWithId:(NSUInteger)taskId
{
    if (taskId == 0) return nil;
    
    for (PiDownloadTask *task in _tasks)
    {
        if (task.identifier == taskId)
        {
            return task;
        }
    }
    PI_WARNING_LOG(@"Can not found task with Identifier : %lu", (unsigned long)taskId);
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

- (PiDownloadTask *) addTaskWithUrl:(NSString *)urlString
{
    PiDownloadTask *task = [self findTaskWithUrlString:urlString];
    if (task == nil)
    {
        task = [PiDownloadTask taskWithURL:urlString];
        [_tasks addObject:task];
        [self saveTaskList];
    }
    return task;
}

- (void) removeTask:(PiDownloadTask *)task
{
    [_tasks removeObject:task];
    [self saveTaskList];
}
@end
