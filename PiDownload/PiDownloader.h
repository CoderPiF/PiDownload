//
//  PiDownloader.h
//  PiDownload
//
//  Created by 江派锋 on 2017/2/16.
//  Copyright © 2017年 Coder.Pi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PiDownloadTask.h"

@interface PiDownloadConfig : NSObject
@property (nonatomic, assign) BOOL autoStartOnLaunch; // 当downloader被创建后会自动开始下载上次正在下载的内容，默认YES
@property (nonatomic, assign) BOOL autoStopOnWWAN; // just iOS，默认YES
@property (nonatomic, assign) int64_t autoSaveResumeSize; // 每隔一定大小(byte)自动保存，just macOS，<=0 表示不保存， 默认0
@property (nonatomic, assign) NSUInteger maxDownloadCount; // 同时下载的任务数，默认1
@property (nonatomic, assign) BOOL autoStartNextTask; // 自动开始下一个任务，默认YES
@end

typedef void(^BgDownloadCompletionHandler)();
@interface PiDownloader : NSObject
@property (nonatomic, readonly) NSString *identifier;
@property (nonatomic, strong) PiDownloadConfig *config;
@property (nonatomic, readonly) NSArray<PiDownloadTask *> *tasks;
@property (nonatomic, copy) BgDownloadCompletionHandler bgCompletionHandler;

+ (PiDownloader *) SharedObject;
- (instancetype) initWithIdentifier:(NSString *)identifier config:(PiDownloadConfig *)config;

- (PiDownloadTask *) addTaskWithUrl:(NSString *)urlString;
- (BOOL) removeTaskWithUrl:(NSString *)urlString;
@end
