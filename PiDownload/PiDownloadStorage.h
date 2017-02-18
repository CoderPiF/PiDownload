//
//  PiDownloadStorage.h
//  PiDownload
//
//  Created by 江派锋 on 2017/2/16.
//  Copyright © 2017年 Coder.Pi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PiDownloadTask.h"

@interface PiDownloadStorage : NSObject
@property (nonatomic, readonly) NSArray<PiDownloadTask *> *tasks;

+ (PiDownloadStorage *) storageWithIdentifier:(NSString *)identifier;

- (PiDownloadTask *) findTaskWithId:(NSUInteger)taskId;
- (PiDownloadTask *) findTaskWithUrlString:(NSString *)urlString;

- (PiDownloadTask *) addTaskWithUrl:(NSString *)urlString;
- (void) removeTask:(PiDownloadTask *)task;
@end
