//
//  PiDownloadTask.h
//  PiDownload
//
//  Created by 江派锋 on 2017/2/16.
//  Copyright © 2017年 Coder.Pi. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PiDownloadTask;
@protocol PiDownloadTaskDelegate <NSObject>
@optional
- (void) onPiDownloadTask:(PiDownloadTask *)task didFinishDownloadToFile:(NSURL *)location;
- (void) onPiDownloadTask:(PiDownloadTask *)task downloadError:(NSError *)error;
- (void) onPiDownloadTask:(PiDownloadTask *)task didUpdateProgress:(float)progress;
@end

typedef NS_ENUM(NSInteger, PiDownloadTaskState)
{
    PiDownloadTaskState_Error       = -1,
    
    PiDownloadTaskState_Running     = 0,
    PiDownloadTaskState_Suspend     = 1,
    PiDownloadTaskState_Canceling   = 2,
    PiDownloadTaskState_Completed   = 3,
};

@interface PiDownloadTask : NSObject
@property (nonatomic, readonly) NSUInteger identifier;
@property (nonatomic, readonly) NSString *downloadURL;
@property (nonatomic, readonly) PiDownloadTaskState state;
@property (nonatomic, readonly) int64_t totalSize;
@property (nonatomic, readonly) int64_t receivedSize;
@property (nonatomic, readonly) NSTimeInterval runningTime;
@property (nonatomic, weak) id<PiDownloadTaskDelegate> delegate;
@property (nonatomic, strong) NSObject<NSCoding> *userData;

- (void) suspend;
- (void) resume;
- (void) cancel;

@end

@interface PiDownloadTask (Progress)
@property (nonatomic, readonly) float progress;
@property (nonatomic, readonly) float speed; // byte/sec
@property (nonatomic, readonly) NSTimeInterval estimationTime;
@end
