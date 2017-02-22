//
//  PiDownloadTaskController.h
//  PiDownload
//
//  Created by 江派锋 on 2017/2/20.
//  Copyright © 2017年 Coder.Pi. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PiDownloadTask;
@class PiDownloadStorage;
@interface PiDownloadTaskController : NSObject
@property (nonatomic, weak) PiDownloadStorage *storage;
@property (nonatomic, assign) NSUInteger maxDownloadCount;
@property (nonatomic, assign) BOOL autoStartNextTask;
@property (nonatomic, assign) BOOL autoStopOnWWAN;

@property (nonatomic, readonly) NSUInteger downloadingCount;
@property (nonatomic, readonly) BOOL canStartTask;

- (void) onTaskStopRunning:(PiDownloadTask *)task;
@end
