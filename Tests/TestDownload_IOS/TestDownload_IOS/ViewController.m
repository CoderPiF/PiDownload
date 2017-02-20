//
//  ViewController.m
//  TestDownload_IOS
//
//  Created by 江派锋 on 2017/2/20.
//  Copyright © 2017年 Coder.Pi. All rights reserved.
//

#import "ViewController.h"
#import <PiDownload/PiDownload.h>

@interface TaskTableViewCell : UITableViewCell <PiDownloadTaskDelegate>
@property (strong, nonatomic) PiDownloadTask *task;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;
@property (weak, nonatomic) IBOutlet UIButton *operateBtn;
@property (weak, nonatomic) IBOutlet UILabel *speedLabel;
@property (weak, nonatomic) IBOutlet UILabel *timeLabel;
@end

@interface ViewController () <UITableViewDataSource, PiDownloadLoggerProtocol>
@property (weak, nonatomic) IBOutlet UITextField *textField;
@property (weak, nonatomic) IBOutlet UITableView *taskTableView;
- (IBAction)addTaskDidPressed:(UIButton *)sender;
@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [PiDownloadLogger setLogger:self];
    PiDownloadConfig *config = [PiDownloadConfig new];
    config.autoStartOnLaunch = NO;
    [PiDownloader SharedObject].config = config;
    
    [_taskTableView reloadData];
}

- (IBAction)addTaskDidPressed:(UIButton *)sender
{
    PiDownloadTask *task = [[PiDownloader SharedObject] addTaskWithUrl:_textField.text];
    task.userData = _textField.text;
    [_taskTableView reloadData];
}

// MARK: - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [PiDownloader SharedObject].tasks.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    TaskTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TaskCellIdentifier"];
    cell.task = [PiDownloader SharedObject].tasks[indexPath.row];
    return cell;
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
    
    [_operateBtn addTarget:self action:@selector(operateDidPressed:) forControlEvents:UIControlEventTouchUpInside];
}

- (NSString *) stateDescribe:(PiDownloadTaskState)state
{
    switch (state) {
        case PiDownloadTaskState_Error: return @"发生错误";
        case PiDownloadTaskState_Waiting: return @"等待中";
        case PiDownloadTaskState_Running: return @"暂停";
        case PiDownloadTaskState_Suspend: return @"开始";
        case PiDownloadTaskState_Canceling: return @"取消";
        case PiDownloadTaskState_Completed: return @"完成";
    }
}

- (void) updateState
{
    NSString *title = [self stateDescribe:_task.state];
    [_operateBtn setTitle:title forState:UIControlStateNormal];
    [_operateBtn setTitle:title forState:UIControlStateHighlighted];
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
        _speedLabel.text = [NSString stringWithFormat:@"%.02lf KB/s", _task.speed / 1024];
    }
    else
    {
        _speedLabel.text = [NSString stringWithFormat:@"%.02lf byte/s", _task.speed];
    }
    
    _timeLabel.text = [NSString stringWithFormat:@"%@ / %@",
                       [self formatTime:_task.runningTime],
                       [self formatTime:_task.estimationTime]];
    
    [self performSelector:@selector(updateTime) withObject:nil afterDelay:1];
}

- (void) setTask:(PiDownloadTask *)task
{
    if (_task == task) return;
    if (_task.delegate == self) _task.delegate = nil;
    
    _task = task;
    _task.delegate = self;
    _titleLabel.text = (NSString *)_task.userData;
    _progressView.progress = _task.progress;
    
    [self updateState];
    [self updateTime];
}

- (void) operateDidPressed:(UIButton *)btn
{
    if (_task.state == PiDownloadTaskState_Running ||
        _task.state == PiDownloadTaskState_Waiting)
    {
        [_task suspend];
    }
    else
    {
        [_task resume];
    }
}

// MARK: - PiDownloadTaskDelegate
- (void) onPiDownloadTask:(PiDownloadTask *)task didStateChange:(PiDownloadTaskState)state
{
    [self updateState];
}

- (void) onPiDownloadTask:(PiDownloadTask *)task didFinishDownloadToFile:(NSURL *)location
{
    // move file
}

- (void) onPiDownloadTask:(PiDownloadTask *)task downloadError:(NSError *)error
{
}

- (void) onPiDownloadTask:(PiDownloadTask *)task didUpdateProgress:(float)progress;
{
    _progressView.progress = progress;
}

@end
