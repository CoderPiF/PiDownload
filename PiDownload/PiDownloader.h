//
//  PiDownloader.h
//  PiDownload
//
//  Created by 江派锋 on 2017/2/16.
//  Copyright © 2017年 Coder.Pi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PiDownloadTask.h"
#import "PiDownloadConfig.h"

typedef void(^BgDownloadCompletionHandler)();
@interface PiDownloader : NSObject
@property (nonatomic, readonly) NSString *identifier;
@property (nonatomic, readonly) NSString *sessionIdentifier;
@property (nonatomic, strong) PiDownloadConfig *config;
@property (nonatomic, readonly) NSArray<PiDownloadTask *> *tasks;
@property (nonatomic, copy) BgDownloadCompletionHandler bgCompletionHandler;

+ (PiDownloader *) SharedObject;
+ (PiDownloader *) downloaderWithIdentifier:(NSString *)identifier config:(PiDownloadConfig *)config;

- (PiDownloadTask *) addTaskWithUrl:(NSString *)urlString toLocalPath:(NSString *)localPath;
- (BOOL) removeTaskWithUrl:(NSString *)urlString;
@end

@interface PiDownloader (Manager)
+ (BOOL) IsPiDownloaderSessionIdentifier:(NSString *)sessionIdentifier;
+ (PiDownloader *) DownloaderWithSessionIdentifier:(NSString *)sessionIdentifier;
+ (PiDownloader *) CreateDownloaderWithSessionIdentifier:(NSString *)sessionIdentifier;
@end
