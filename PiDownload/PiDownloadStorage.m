//
//  PiDownloadStorage.m
//  PiDownload
//
//  Created by 江派锋 on 2017/2/16.
//  Copyright © 2017年 Coder.Pi. All rights reserved.
//

#import "PiDownloadStorage.h"
#import "PiDownloadLogger.h"
#import "PiDownloader.h"
#import "PiDownloadTaskImp.h"
#import <CommonCrypto/CommonDigest.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif

static NSString * MD5String(NSString *string)
{
    const char *cStr = [string UTF8String];
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    
    CC_MD5(cStr, (CC_LONG)strlen(cStr), digest);
    
    NSMutableString *result = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
    {
        [result appendFormat:@"%02X", digest[i]];
    }
    
    return result;
}

@interface PiDownloadStorage ()<PiDownloadTaskResumeData>
{
    NSMutableArray<PiDownloadTask *> *_tasks;
    NSString *_storagePath;
}
@end

@implementation PiDownloadStorage
+ (NSString *) StoragePathWithId:(NSString *)identifier
{
    NSString *documentDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *path = [documentDirectory stringByAppendingPathComponent:identifier];
    BOOL isDirectory = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory] || !isDirectory)
    {
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return path;
}

+ (PiDownloadStorage *) storageWithIdentifier:(NSString *)identifier
{
    return [[PiDownloadStorage alloc] initWithIdentifier:identifier];
}

+ (NSString *) ConfigPathWithIdentifier:(NSString *)identifier
{
    NSString *path = [self StoragePathWithId:identifier];
    return [path stringByAppendingPathComponent:@"Config"];
}

+ (PiDownloadConfig *) readLastConfigWithIdentifier:(NSString *)identifier
{
    NSString *path = [self ConfigPathWithIdentifier:identifier];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path])
    {
        return [NSKeyedUnarchiver unarchiveObjectWithFile:path];
    }
    return [PiDownloadConfig new];
}

+ (BOOL) saveConfig:(PiDownloadConfig *)config forIdentifier:(NSString *)identifier
{
    NSString *path = [self ConfigPathWithIdentifier:identifier];
    if (config == nil)
    {
        return [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }
    else
    {
        return [NSKeyedArchiver archiveRootObject:config toFile:path];
    }
}

- (NSString *) tasksDataPath
{
    return [_storagePath stringByAppendingPathComponent:@"TasksData"];
}

- (void) readTaskListWithIdentifier:(NSString *)identifier
{
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.tasksDataPath])
    {
        _tasks = ((NSArray *)[NSKeyedUnarchiver unarchiveObjectWithFile:self.tasksDataPath]).mutableCopy;
        for (PiDownloadTask *task in _tasks)
        {
            task.resumeDataStorage = self;
        }
    }
    
    if (_tasks == nil)
    {
        _tasks = [NSMutableArray array];
    }
}

- (void) appWillTerminate
{
#if !(TARGET_OS_IPHONE)
    for (PiDownloadTask *task in _tasks)
    {
        [task stopAndSaveResumeData];
    }
#endif
    
    if (![NSKeyedArchiver archiveRootObject:_tasks toFile:self.tasksDataPath])
    {
        PI_ERROR_LOG(@"Save Task List Fail");
    }
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype) initWithIdentifier:(NSString *)identifier
{
    self = [super init];
    if (self)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appWillTerminate)
#if TARGET_OS_IPHONE
                                                     name:UIApplicationWillTerminateNotification
#else
                                                     name:NSApplicationWillTerminateNotification
#endif
                                                   object:nil];
        _storagePath = [self.class StoragePathWithId:identifier];
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
        task.resumeDataStorage = self;
        [_tasks addObject:task];
    }
    return task;
}

- (void) removeTask:(PiDownloadTask *)task
{
    task.resumeData = nil;
    [_tasks removeObject:task];
}

// MARK: - PiDownloadTaskResumeData
+ (NSString *) getLocalPathFromResumeData:(NSData *)resumeData
{
    if (resumeData == nil) return nil;
    
    NSError *error;
    id resumeDictionary = [NSPropertyListSerialization propertyListWithData:resumeData options:NSPropertyListImmutable format:nil error:&error];
    if (resumeDictionary == nil || error != nil) return nil;
    
    NSString *localFilePath = resumeDictionary[@"NSURLSessionResumeInfoLocalPath"];
    if (localFilePath.length < 1)
    {
        localFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:resumeDictionary[@"NSURLSessionResumeInfoTempFileName"]];
    }
    
    return localFilePath;
}

+ (BOOL) isValidresumeData:(NSData *)resumeData
{
    NSString *localFilePath = [PiDownloadStorage getLocalPathFromResumeData:resumeData];
    if (localFilePath.length < 1) return NO;
    return [[NSFileManager defaultManager] fileExistsAtPath:localFilePath];
}

+ (NSString *) localPathWithResumeFile:(NSString *)resumeFilePath
{
    return [resumeFilePath stringByAppendingPathExtension:@"tmp"];
}

- (NSString *) resumeDataPathWithTask:(PiDownloadTask *)task
{
    NSString *name = MD5String(task.downloadURL);
    return [_storagePath stringByAppendingPathComponent:name];
}

- (void) onPidDownloadTask:(PiDownloadTask *)task saveResumeData:(NSData *)resumeData
{
    NSString *path = [self resumeDataPathWithTask:task];
    NSString *tmp = [self.class localPathWithResumeFile:path];
    if (resumeData == nil)
    {
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:tmp error:nil];
    }
    else
    {
        [resumeData writeToFile:path atomically:YES];
        
        NSString *tmpTarget = [self.class getLocalPathFromResumeData:resumeData];
        if (tmpTarget.length > 0)
        {
            [[NSFileManager defaultManager] copyItemAtPath:tmpTarget toPath:tmp error:nil];
        }
    }
}

- (NSData *) onPiDownloadTaskReadResumeData:(PiDownloadTask *)task
{
    NSString *path = [self resumeDataPathWithTask:task];
    NSString *tmp = [self.class localPathWithResumeFile:path];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:path])
    {
        NSData *resumeData = [NSData dataWithContentsOfFile:path];
        NSString *localPath = [self.class getLocalPathFromResumeData:resumeData];
        if (localPath.length > 0 && [fileManager fileExistsAtPath:tmp] && ![fileManager fileExistsAtPath:localPath])
        {
            [fileManager copyItemAtPath:tmp toPath:localPath error:nil];
        }
        return resumeData;
    }
    return nil;
}
@end
