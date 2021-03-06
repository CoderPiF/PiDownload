//
//  ViewController.m
//  TestDownload_MacOS
//
//  Created by 江派锋 on 2017/2/16.
//  Copyright © 2017年 Coder.Pi. All rights reserved.
//

#import "ViewController.h"
#import <PiDownload/PiDownload.h>

@interface ViewController () <NSTableViewDelegate, NSTableViewDataSource, PiDownloadLoggerProtocol>
@property (weak) IBOutlet NSTextField *urlTextField;
@property (weak) IBOutlet NSTableView *downloadTableView;
@end

@interface TaskTableViewCell : NSTableCellView <PiDownloadTaskDelegate>
@property (weak) IBOutlet NSTextField *urlStringLabel;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (weak) IBOutlet NSButton *taskOperateBtn;
@property (weak) IBOutlet NSTextField *speedLabel;
@property (weak) IBOutlet NSTextField *timeLabel;
@property (nonatomic) PiDownloadTask *task;
@end

@implementation ViewController

- (NSString *) localPathForUrl:(NSString *)url
{
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    return [path stringByAppendingPathComponent:[url lastPathComponent]];
}

- (IBAction)addTask:(NSButton *)sender
{
    NSString *path = [self localPathForUrl:_urlTextField.stringValue];
    PiDownloadTask *task = [[PiDownloader SharedObject] addTaskWithUrl:_urlTextField.stringValue toLocalPath:path];
    task.userData = _urlTextField.stringValue;
    [_downloadTableView reloadData];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [PiDownloadLogger setLogger:self];
    _downloadTableView.delegate = self;
    _downloadTableView.dataSource = self;
    [_downloadTableView reloadData];
}


// MARK: - NSTableViewDelegate
- (NSView *) tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    TaskTableViewCell *cell = [tableView makeViewWithIdentifier:@"TaskCellIdentifier" owner:self];
    cell.task = [PiDownloader SharedObject].tasks[row];
    return cell;
}

// MARK: - NSTableViewDataSource
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [PiDownloader SharedObject].tasks.count;
}

// MARK: - PiDownloadLoggerProtocol
- (void) onPiDownloadLoggerWithLevel:(PiDownloadLoggerLevel)level msg:(NSString *)msg
{
    NSLog(@"[%ld] %@", level, msg);
}

@end

@implementation TaskTableViewCell

- (void) dealloc
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (void) awakeFromNib
{
    [super awakeFromNib];
    
    [_taskOperateBtn setTarget:self];
    [_taskOperateBtn setAction:@selector(operateTask:)];
    
    PiDownloadConfig *config = [PiDownloadConfig new];
    config.autoSaveResumeSize = 1024 * 1024 * 2;
    config.maxDownloadCount = 2;
    [PiDownloader SharedObject].config = config;
}

- (void) operateTask:(NSButton *)btn
{
    if (_task.state == PiDownloadTaskState_Running)
    {
        [_task suspend];
    }
    else
    {
        [_task resume];
    }
    
    [self updateStatus];
}

- (void) updateStatus
{
    switch (_task.state) {
        case PiDownloadTaskState_Error: _taskOperateBtn.title = @"发生错误"; break;
        case PiDownloadTaskState_Waiting: _taskOperateBtn.title = @"等待中"; break;
        case PiDownloadTaskState_Running: _taskOperateBtn.title = @"暂停"; break;
        case PiDownloadTaskState_Suspend: _taskOperateBtn.title = @"开始"; break;
        case PiDownloadTaskState_Canceling: _taskOperateBtn.title = @"取消"; break;
        case PiDownloadTaskState_Completed: _taskOperateBtn.title = @"完成"; break;
    }
}

- (void) setTask:(PiDownloadTask *)task
{
    if (_task == task) return;
    if (_task.delegate == self) _task.delegate = nil;
    
    _task = task;
    _task.delegate = self;
    _urlStringLabel.stringValue = (NSString *)task.userData;
    _progressIndicator.doubleValue = task.progress * 100;
    
    [self updateStatus];
    [self updateTime];
}

- (NSString *)formatTime:(NSTimeInterval)time
{
    uint64_t t = time;
    uint64_t hour = t / (60 * 60);
    t %= (60 * 60);
    uint64_t min = t / 60;
    uint64_t sec = t % 60;
    return [NSString stringWithFormat:@"%02llu:%02llu:%02llu", hour, min, sec];
}

- (void) updateTime
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateTime) object:nil];
    if (_task.speed > 1024)
    {
        _speedLabel.stringValue = [NSString stringWithFormat:@"%.02lf KB/s", _task.speed / 1024];
    }
    else
    {
        _speedLabel.stringValue = [NSString stringWithFormat:@"%.02lf byte/s", _task.speed];
    }
    
    _timeLabel.stringValue = [NSString stringWithFormat:@"%@ / %@",
                              [self formatTime:_task.runningTime],
                              [self formatTime:_task.estimationTime]];
    
    [self performSelector:@selector(updateTime) withObject:nil afterDelay:1];
}

// MARK: - PiDownloadTaskDelegate
- (void) onPiDownloadTask:(PiDownloadTask *)task didFinishDownloadToFile:(NSURL *)location
{
    NSLog(@"location : %@", location.absoluteString);
    [self updateStatus];
}

- (void) onPiDownloadTask:(PiDownloadTask *)task downloadError:(NSError *)error
{
    NSLog(@"error : %@", error);
    [self updateStatus];
}

- (void) onPiDownloadTask:(PiDownloadTask *)task didUpdateProgress:(float)progress
{
    _progressIndicator.doubleValue = task.progress * 100;
}

- (void) onPiDownloadTask:(PiDownloadTask *)task didStateChange:(PiDownloadTaskState)state
{
    [self updateStatus];
}
@end
