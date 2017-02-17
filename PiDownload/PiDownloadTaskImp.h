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

@class PiDownloader;
@interface PiDownloadTask (Downloader)
@property (nonatomic) NSData *resumeData;
@property (weak) id<PiDownloadTaskCreator> taskCreator;

- (void) ready;
- (BOOL) isValidresumeData;
- (void) onDownloader:(PiDownloader *)downloader didCompleteWithError:(NSError *)error;
- (void) onDownloader:(PiDownloader *)downloader didFinishToURL:(NSURL *)location;
- (void) onDownloader:(PiDownloader *)downloader didWriteData:(int64_t)bytesWritten totalWritten:(int64_t)totalWritten totalExpected:(int64_t)totalExpected;
@end

// MARK: - for Storage
@interface PiDownloadTask (Storage) <NSCoding>
+ (PiDownloadTask *) taskWithURL:(NSString *)url;
@end

#endif /* PiDownloadTaskImp_h */
