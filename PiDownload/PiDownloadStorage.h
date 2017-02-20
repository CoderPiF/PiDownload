//
//  PiDownloadStorage.h
//  PiDownload
//
//  Created by 江派锋 on 2017/2/16.
//  Copyright © 2017年 Coder.Pi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PiDownloadTask.h"

@class PiDownloadConfig;
@interface PiDownloadStorage : NSObject
@property (nonatomic, readonly) NSArray<PiDownloadTask *> *tasks;

+ (PiDownloadStorage *) storageWithIdentifier:(NSString *)identifier;

+ (PiDownloadConfig *) readLastConfigWithIdentifier:(NSString *)identifier;
+ (BOOL) saveConfig:(PiDownloadConfig *)config forIdentifier:(NSString *)identifier;
+ (BOOL) isValidresumeData:(NSData *)resumeData;

+ (NSString *) getLocalPathFromResumeData:(NSData *)resumeData;

- (PiDownloadTask *) findTaskWithId:(NSUInteger)taskId;
- (PiDownloadTask *) findTaskWithUrlString:(NSString *)urlString;

- (PiDownloadTask *) addTaskWithUrl:(NSString *)urlString;
- (void) removeTask:(PiDownloadTask *)task;
@end
