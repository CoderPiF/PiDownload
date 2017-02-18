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
@property (nonatomic, assign) BOOL autoStartOnLaunch;
@property (nonatomic, assign) BOOL autoStopOnWWAN;
@end

typedef void(^BgDownloadCompletionHandler)();
@interface PiDownloader : NSObject
@property (nonatomic, readonly) NSString *identifier;
@property (nonatomic, strong) PiDownloadConfig *config;
@property (nonatomic, readonly) NSArray<PiDownloadTask *> *tasks;
@property (nonatomic, copy) BgDownloadCompletionHandler bgCompletionHandler;

+ (PiDownloader *) SharedObject;
- (instancetype) initWithIdentifier:(NSString *)identifier;

- (PiDownloadTask *) addTaskWithUrl:(NSString *)urlString;
- (BOOL) removeTaskWithUrl:(NSString *)urlString;
@end
