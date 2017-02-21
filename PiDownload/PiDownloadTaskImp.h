//
//  PiDownloadTaskImp.h
//  PiDownload
//
//  Created by 江派锋 on 2017/2/17.
//  Copyright © 2017年 Coder.Pi. All rights reserved.
//

#ifndef PiDownloadTaskImp_h
#define PiDownloadTaskImp_h

#import "PiDownloadTask.h"

// MARK: - for Downloader
@protocol PiDownloadTaskCreator <NSObject>
- (NSURLSessionDownloadTask *) onDownloadTaskCreate:(PiDownloadTask *)task;
@end

@class PiDownloadTaskController;
@class PiDownloader;
@interface PiDownloadTask (Downloader)
@property (weak) PiDownloadTaskController *controller;
@property (nonatomic) NSData *resumeData;
@property (nonatomic) PiDownloadTaskState state;
@property (weak) id<PiDownloadTaskCreator> taskCreator;
@property (nonatomic) int64_t autoSaveResumeSize;

- (void) ready;
- (BOOL) isValidresumeData;
- (void) onDownloader:(PiDownloader *)downloader didCompleteWithError:(NSError *)error;
- (void) onDownloader:(PiDownloader *)downloader didFinishToURL:(NSURL *)location;
- (void) onDownloader:(PiDownloader *)downloader didWriteData:(int64_t)bytesWritten totalWritten:(int64_t)totalWritten totalExpected:(int64_t)totalExpected;
@end

// MARK: - for Storage
@protocol PiDownloadTaskResumeData <NSObject>
- (void) onPidDownloadTask:(PiDownloadTask *)task saveResumeData:(NSData *)resumeData;
- (NSData *) onPiDownloadTaskReadResumeData:(PiDownloadTask *)task;
@end

@interface PiDownloadTask (Storage) <NSCoding>
@property (weak) id<PiDownloadTaskResumeData> resumeDataStorage;
+ (PiDownloadTask *) taskWithURL:(NSString *)url;

- (void) stopAndSaveResumeData;
@end

#endif /* PiDownloadTaskImp_h */
