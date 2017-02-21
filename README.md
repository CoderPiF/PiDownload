# PiDownload
iOS / macOS 后台断点下载

# 安装
`pod 'PiDownload'`

# 使用

## 头文件
`#import <PiDownload/PiDownload.h>`

## Downloader
1. `[PiDownloader SharedObject]`
2. `[PiDownloader downloadWithIdentifier:@"yourIdentifier" config:yourConfig]`

## 配置(PiDownloadConfig)
1. `autoStartOnLaunch` : 自动下载上次正在下载或者等待下载的内容。默认YES.
2. `autoStopOnWWAN` : 当处于WWAN网络时自动停止下载（只针对iOS有用）。默认YES.
3. `autoSaveResumeSize` : 下载每隔一段大小(byte)自动保存一下（针对macOS)，<=0表示不保存。默认0.
4. `maxDownloadCount` : 最大同时下载的任务数。默认1.
5. `autoStartNextTask` : 自动开始下一个等待中的任务。默认YES.

## 添加任务
`[[PiDownloader SharedObject] addTaskWithUrl:@"http://xxx" toLocalPath:@"/xxx/yourLocalPath"]`

## iOS 后台下载回调
```objective-c
- (void) application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)())completionHandler
{
    if ([PiDownloader IsPiDownloaderSessionIdentifier:identifier])
    {
        PiDownloader *downloader = [PiDownloader DownloaderWithSessionIdentifier:identifier];
        if (downloader == nil)
        {
            downloader = [PiDownloader CreateDownloaderWithSessionIdentifier:identifier];
        }
        downloader.bgCompletionHandler = completionHandler;
    }
}
```

# 注意
本库只负责下载，所以只管理未下载完成的任务，对应已取消和已完成的任务回调完成后会直接移除任务。
