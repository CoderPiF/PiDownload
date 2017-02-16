//
//  PiDownloadLogger.h
//  PiDownload
//
//  Created by 江派锋 on 2017/2/16.
//  Copyright © 2017年 Coder.Pi. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, PiDownloadLoggerLevel)
{
    PiDownloadLoggerLevel_Debug     = 0,
    PiDownloadLoggerLevel_Info      = 1,
    PiDownloadLoggerLevel_Warning   = 2,
    PiDownloadLoggerLevel_Error     = 3,
};

@protocol PiDownloadLoggerProtocol <NSObject>
- (void) onPiDownloadLoggerWithLevel:(PiDownloadLoggerLevel)level msg:(NSString *)msg;
@end

@interface PiDownloadLogger : NSObject
+ (void) setLogger:(id<PiDownloadLoggerProtocol>)logger;
+ (void) logWithLevel:(PiDownloadLoggerLevel)level msg:(NSString *)msg;
@end

#define PI_LOG(level, fmt, ...) [PiDownloadLogger logWithLevel:level msg:[NSString stringWithFormat:fmt, ##__VA_ARGS__]]
#define PI_DEBUG_LOG(fmt, ...) PI_LOG(PiDownloadLoggerLevel_Debug, fmt, ##__VA_ARGS__)
#define PI_INFO_LOG(fmt, ...) PI_LOG(PiDownloadLoggerLevel_Info, fmt, ##__VA_ARGS__)
#define PI_WARNING_LOG(fmt, ...) PI_LOG(PiDownloadLoggerLevel_Warning, fmt, ##__VA_ARGS__)
#define PI_ERROR_LOG(fmt, ...) PI_LOG(PiDownloadLoggerLevel_Error, fmt, ##__VA_ARGS__)
