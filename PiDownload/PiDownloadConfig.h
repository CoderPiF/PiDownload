//
//  PiDownloadConfig.h
//  PiDownload
//
//  Created by 江派锋 on 2017/2/22.
//  Copyright © 2017年 Coder.Pi. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PiDownloadConfig : NSObject
@property (nonatomic, assign) BOOL autoStartOnLaunch; // 自动下载上次正在下载或者等待下载的内容。默认YES.
@property (nonatomic, assign) BOOL autoStopOnWWAN; // 当处于WWAN网络时自动停止下载（只针对iOS有用）。默认YES.
@property (nonatomic, assign) int64_t autoSaveResumeSize; // 下载每隔一段大小(byte)自动保存一下（针对macOS)，<=0表示不保存。默认0.
@property (nonatomic, assign) NSUInteger maxDownloadCount; // 最大同时下载的任务数。默认1.
@property (nonatomic, assign) BOOL autoStartNextTask; // 自动开始下一个等待中的任务。默认YES.
@end
