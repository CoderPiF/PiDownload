//
//  PiDownloadLogger.m
//  PiDownload
//
//  Created by 江派锋 on 2017/2/16.
//  Copyright © 2017年 Coder.Pi. All rights reserved.
//

#import "PiDownloadLogger.h"

@interface PiDownloadLogger ()
@property (nonatomic, weak) id<PiDownloadLoggerProtocol> logger;
@end

@implementation PiDownloadLogger

+ (PiDownloadLogger *) Instance
{
    static PiDownloadLogger *s_shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_shared = [PiDownloadLogger new];
    });
    return s_shared;
}

- (void) logWithLevel:(PiDownloadLoggerLevel)level msg:(NSString *)msg
{
    if ([_logger respondsToSelector:@selector(onPiDownloadLoggerWithLevel:msg:)])
    {
        msg = [NSString stringWithFormat:@"[PiDownload]: %@", msg];
        [_logger onPiDownloadLoggerWithLevel:level msg:msg];
    }
}

+ (void) setLogger:(id<PiDownloadLoggerProtocol>)logger
{
    self.Instance.logger = logger;
}

+ (void) logWithLevel:(PiDownloadLoggerLevel)level msg:(NSString *)msg
{
    [self.Instance logWithLevel:level msg:msg];
}

@end
