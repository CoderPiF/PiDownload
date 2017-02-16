//
//  PiDownloader.h
//  PiDownload
//
//  Created by 江派锋 on 2017/2/16.
//  Copyright © 2017年 Coder.Pi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PiDownloadTask.h"

typedef void(^BgDownloadCompletionHandler)();
@interface PiDownloader : NSObject
@property (nonatomic, readonly) NSString *identifier;
@property (nonatomic, readonly) NSArray<PiDownloadTask *> *tasks;
@property (nonatomic, copy) BgDownloadCompletionHandler bgCompletionHandler;

+ (PiDownloader *) SharedObject;
- (instancetype) initWithIdentifier:(NSString *)identifier;

- (BOOL) addTask:(PiDownloadTask *)task;
- (BOOL) removeTask:(PiDownloadTask *)task;
@end
