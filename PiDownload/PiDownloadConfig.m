//
//  PiDownloadConfig.m
//  PiDownload
//
//  Created by 江派锋 on 2017/2/22.
//  Copyright © 2017年 Coder.Pi. All rights reserved.
//

#import "PiDownloadConfig.h"

@implementation PiDownloadConfig
- (instancetype) init
{
    self = [super init];
    if (self)
    {
        _autoStartOnLaunch = YES;
        _autoStopOnWWAN = YES;
        _autoSaveResumeSize = 0;
        _maxDownloadCount = 1;
        _autoStartNextTask = YES;
    }
    return self;
}

#define kClassVersionKey        @"ClassVersion"
#define kAutoSaveResumeSizeKey  @"AutoSaveResumeSizeKey"
#define kAutoStopOnWWANKey      @"AutoStopOnWWAN"
#define kAutoStartOnLaunchKey   @"AutoStartOnLaunch"
#define kMaxDownloadCountKey    @"MaxDownloadCount"
#define kAutoStartNextTaskKey   @"AutoStartNextTask"
+ (NSInteger) version
{
    return 1;
}

- (instancetype) initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self)
    {
        self.autoSaveResumeSize = [aDecoder decodeInt64ForKey:kAutoSaveResumeSizeKey];
        self.autoStopOnWWAN = [aDecoder decodeBoolForKey:kAutoStopOnWWANKey];
        self.autoStartOnLaunch = [aDecoder decodeBoolForKey:kAutoStartOnLaunchKey];
        self.maxDownloadCount = [aDecoder decodeIntegerForKey:kMaxDownloadCountKey];
        self.autoStartNextTask = [aDecoder decodeBoolForKey:kAutoStartNextTaskKey];
    }
    return self;
}

- (void) encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInteger:self.class.version forKey:kClassVersionKey];
    [aCoder encodeBool:self.autoStartOnLaunch forKey:kAutoStartOnLaunchKey];
    [aCoder encodeBool:self.autoStopOnWWAN forKey:kAutoStopOnWWANKey];
    [aCoder encodeInt64:self.autoSaveResumeSize forKey:kAutoSaveResumeSizeKey];
    [aCoder encodeInteger:self.maxDownloadCount forKey:kMaxDownloadCountKey];
    [aCoder encodeBool:self.autoStartNextTask forKey:kAutoStartNextTaskKey];
}

@end
