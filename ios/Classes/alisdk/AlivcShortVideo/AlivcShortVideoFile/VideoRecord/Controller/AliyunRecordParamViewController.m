//
//  QURecordParamViewController.m
//  AliyunVideo
//
//  Created by dangshuai on 17/3/6.
//  Copyright (C) 2010-2017 Alibaba Group Holding Limited. All rights reserved.
//

#import "AliyunRecordParamViewController.h"
#import "AliyunRecordParamTableViewCell.h"
#import "AVC_ShortVideo_Config.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "AliyunMagicCameraViewController.h"
#import "AliyunMediaConfig.h"
#import "AliyunMediator.h"
#import "AlivcUIConfig.h"
#import "AlivcShortVideoRoute.h"
#import <AliyunVideoSDKPro/AliyunVideoSDKPro.h>
//#import "AliyunCompositionViewController.h"
@interface AliyunRecordParamViewController ()<UITableViewDataSource,UITableViewDelegate>

/**
 tavleView的距离底部的约束
 */
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *tableViewBottomConstraint;
    
/**
 中间view
 */
@property (weak, nonatomic) IBOutlet UITableView *tableView;

/**
 数据模型数组
 */
@property (nonatomic, strong) NSArray *dataArray;

/**
 录制参数
 */
@property (nonatomic, strong) AliyunMediaConfig *quVideo;

/**
 分辨率
 */
@property (nonatomic, assign) CGFloat videoOutputWidth;

/**
 视频比例
 */
@property (nonatomic, assign) CGFloat videoOutputRatio;


/**
 录制方式
 */
@property (nonatomic, assign) AlivcRecordType recordType;

/**
 顶部view距离最顶部的约束
 */
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *heightConstraint;
@property (weak, nonatomic) IBOutlet UIButton *rightButton;
@property (weak, nonatomic) UIButton *recordButton;
@property (assign, nonatomic) CGFloat maxDuration;
@property (weak, nonatomic) IBOutlet UILabel *paramTitleLabel;
@end

@implementation AliyunRecordParamViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.paramTitleLabel.text = NSLocalizedString(@"录制参数", nil);
    [AliyunIConfig config].hiddenImportButton = NO;
    self.automaticallyAdjustsScrollViewInsets = NO;
    [self setupParamData];
    [_tableView reloadData];
    self.heightConstraint.constant = SafeTop;
    self.tableViewBottomConstraint.constant = SafeBottom + 74;
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hiddenKeyboard)];
    [self.tableView addGestureRecognizer:tapGesture];
    
    _quVideo = [AliyunMediaConfig defaultConfig];
    _quVideo.minDuration = 2;
     _maxDuration = 15;
    _quVideo.maxDuration = 15;
    _quVideo.gop = 30;
   
    self.videoOutputRatio = 9.0f / 16.0f;
    self.videoOutputWidth = _quVideo.outputSize.width;
    self.view.backgroundColor = [AlivcUIConfig shared].kAVCBackgroundColor;
    
    UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(0, ScreenHeight-44-SafeBottom, ScreenWidth, 44)];
    [button setTitle:NSLocalizedString(@"开启录制界面", nil) forState:0];
    button.titleLabel.font = [UIFont systemFontOfSize:16];
    [button addTarget:self action:@selector(toRecordView) forControlEvents:UIControlEventTouchUpInside];
    button.backgroundColor = AlivcOxRGB(0x00c1de);
    [self.view addSubview:button];
 
    self.recordButton = button;
    self.rightButton.hidden = YES;

 
 
}

- (IBAction)rightButtonClick:(UIButton *)sender {
    if ([[sender titleForState:UIControlStateNormal] isEqualToString:NSLocalizedString(@"硬编", nil)]) {
        [sender setTitle:NSLocalizedString(@"软编", nil) forState:UIControlStateNormal];
        _quVideo.encodeMode = AliyunEncodeModeSoftFFmpeg;
    }else{
        [sender setTitle:NSLocalizedString(@"硬编", nil) forState:UIControlStateNormal];
        _quVideo.encodeMode = AliyunEncodeModeHardH264;
    }
}

/**
 控制器view的点击手势触发事件
 */
- (void)hiddenKeyboard {
    [self.view endEditing:YES];
}


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [[UIApplication sharedApplication] setStatusBarHidden:NO];

}

// 支持设备自动旋转
- (BOOL)shouldAutorotate
{
    return YES;
}

// 支持竖屏显示
- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

#pragma mark - UITableViewDelegate&&UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    
    return _dataArray.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
     AliyunRecordParamCellModel *model = _dataArray[indexPath.row];
    if ([model.reuseId isEqualToString:@"cellInput"]) {
        return 95;
    }else{
        if (indexPath.row == 4 || indexPath.row == 6) {
            return 82;
        }
        else{
            return 133;
        }
    }
    
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    
    AliyunRecordParamCellModel *model = _dataArray[indexPath.row];
    if (model) {
        NSString *identifier = model.reuseId;
        if([identifier isEqualToString:@"cellInput"]){
            AliyunRecordParamTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
            if (!cell) {
                cell = [[AliyunRecordParamTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
            }
            [cell configureCellModel:model];
            return cell;
        }else{
            AliyunRecordParamTableViewCell *cell = [[AliyunRecordParamTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
            [cell configureCellModel:model];
            return cell;
        }
        
    }
    return nil;
}


/**
 设置tableView的数据
 */
- (void)setupParamData {
    __weak typeof(self)weakSelf = self;

    AliyunRecordParamCellModel *cellModel1 = [[AliyunRecordParamCellModel alloc] init];
    cellModel1.title = NSLocalizedString(@"最小时长", nil);
    cellModel1.placeHolder = NSLocalizedString(@"最小时长大于0，默认值2s", nil);
    cellModel1.reuseId = @"cellInput";
    cellModel1.defaultValue = 2;
    cellModel1.value = 2;
    cellModel1.valueBlock = ^(int value){
        weakSelf.quVideo.minDuration = value;
    };
    
    AliyunRecordParamCellModel *cellModel2 = [[AliyunRecordParamCellModel alloc] init];
    cellModel2.title = NSLocalizedString(@"最大时长", nil);
    cellModel2.placeHolder = NSLocalizedString(@"不超过300S，默认值15s", nil);
    cellModel2.reuseId = @"cellInput";
    cellModel2.defaultValue = 15;
    cellModel2.value = 15;
    cellModel2.valueBlock = ^(int value){
        weakSelf.quVideo.maxDuration = value;
        weakSelf.maxDuration = value;
    };
    
    AliyunRecordParamCellModel *cellModel3 = [[AliyunRecordParamCellModel alloc] init];
    cellModel3.title = NSLocalizedString(@"关键帧间隔", nil);
    cellModel3.placeHolder = NSLocalizedString(@"建议1-300，默认30", nil);
    cellModel3.reuseId = @"cellInput";
    cellModel3.defaultValue = 30;
    cellModel3.value = 30;
    cellModel3.valueBlock = ^(int value) {
        weakSelf.quVideo.gop = value;
    };
    
    AliyunRecordParamCellModel *cellModel4 = [[AliyunRecordParamCellModel alloc] init];
    cellModel4.title = NSLocalizedString(@"视频质量", nil);
    cellModel4.buttonTitleArray = @[NSLocalizedString(@"优质", nil),NSLocalizedString(@"良好", nil),NSLocalizedString(@"一般", nil),NSLocalizedString(@"较差", nil)];
    cellModel4.placeHolder = NSLocalizedString(@"良好", nil);
    cellModel4.reuseId = @"cellSilder";
    cellModel4.defaultValue = 0.75;
    cellModel4.value = 0.75;
    cellModel4.valueBlock = ^(int value){
        weakSelf.quVideo.videoQuality = value;
    };
    
    AliyunRecordParamCellModel *cellModel5 = [[AliyunRecordParamCellModel alloc] init];
    cellModel5.title = NSLocalizedString(@"视频比例", nil);
    cellModel5.buttonTitleArray = @[@"9:16",@"3:4",@"1:1"];
    cellModel5.placeHolder = @"9:16";
    cellModel5.reuseId = @"cellSilder";
    cellModel5.defaultValue = 1.0;
    cellModel5.value = 1.0;
    cellModel5.ratioBack = ^(CGFloat videoRatio){
        weakSelf.videoOutputRatio = videoRatio;
    };
    
    AliyunRecordParamCellModel *cellModel6 = [[AliyunRecordParamCellModel alloc] init];
    cellModel6.title = NSLocalizedString(@"分辨率", nil);
    cellModel6.buttonTitleArray = @[@"360p",@"480p",@"540p",@"720p"];
    cellModel6.placeHolder = @"720p";
    cellModel6.reuseId = @"cellSilder";
    cellModel6.defaultValue = 0.75;
    cellModel6.defaultValue = 0.75;
    cellModel6.sizeBlock = ^(CGFloat videoWidth){
        weakSelf.videoOutputWidth = videoWidth;
    };
    
    AliyunRecordParamCellModel *cellModel7 = [[AliyunRecordParamCellModel alloc] init];
    cellModel7.title = NSLocalizedString(@"视频编码方式", nil);
    cellModel7.buttonTitleArray = @[NSLocalizedString(@"硬编", nil),NSLocalizedString(@"软编", nil)];
    cellModel7.placeHolder = NSLocalizedString(@"硬编", nil);
    cellModel7.reuseId = @"cellSilder";
    cellModel7.encodeModelBlock = ^(NSInteger encodeMode) {
        weakSelf.quVideo.encodeMode = (AliyunEncodeMode)encodeMode;
    };
    
    AliyunRecordParamCellModel *cellModel8 = [[AliyunRecordParamCellModel alloc] init];
    cellModel8.title = @"拍摄方式";
    cellModel8.buttonTitleArray = @[@"普通",@"合拍"];
    cellModel8.placeHolder = @"普通";
    cellModel8.reuseId = @"cellSilder";
    cellModel8.recodeTypeBlock = ^(AlivcRecordType recordType) {
        weakSelf.recordType = recordType;
    };
    
//    cellModel6.defaultValue = 0.75;
//    cellModel6.sizeBlock = ^(CGFloat videoWidth){
//        weakSelf.quVideo.encodeMode = AliyunEncodeMode()
//    };
 
//    _dataArray = @[cellModel0,cellModel1,cellModel2,cellModel3,cellModel4,cellModel5,cellModel6,cellModel7,cellModel8];
    _dataArray = @[cellModel1,cellModel2,cellModel3,cellModel4,cellModel5,cellModel6,cellModel7,cellModel8];

}

// 根据调节结果更新videoSize
- (void)updatevideoOutputVideoSize {
    
    CGFloat width = self.videoOutputWidth;
    CGFloat height = ceilf(self.videoOutputWidth / self.videoOutputRatio); // 视频的videoSize需为整偶数
    _quVideo.outputSize = CGSizeMake(width, height);
    NSLog(@"videoSize:w:%f  h:%f", _quVideo.outputSize.width, _quVideo.outputSize.height);
}

/**
 返回按钮的点击事件

 @param sender 返回按钮
 */
- (IBAction)buttonBackClick:(id)sender {
    
    [self.navigationController popViewControllerAnimated:YES];
    
}

/**
 进入录制界面
 */
- (void)toRecordView {
    [self.view endEditing:YES];
    
    [self updatevideoOutputVideoSize];
    _quVideo.maxDuration = self.maxDuration;
    if((_quVideo.maxDuration == 0)&&(_quVideo.minDuration == 0)){
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"提示", nil) message:NSLocalizedString(@"最大时长不小于最小时长", nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"确定" , nil) otherButtonTitles: nil];
        [alert show];
        return;
    }
    
    if(_quVideo.minDuration == 0){
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"提示", nil) message:NSLocalizedString(@"最小时长要大于0", nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"确定" , nil) otherButtonTitles: nil];
        [alert show];
        return;
    }
    
    
    if (_quVideo.maxDuration <= _quVideo.minDuration ) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"提示", nil) message:NSLocalizedString(@"最大时长不小于最小时长", nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"确定" , nil) otherButtonTitles: nil];
        [alert show];
        return;
    }
    if (_quVideo.maxDuration > 300 ) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"提示", nil) message:NSLocalizedString(@"最大时长不能超过300s", nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"确定" , nil) otherButtonTitles: nil];
        [alert show];
        return;
    }
    if (self.recordType == AlivcRecordTypeNormal) {
        //配置
        [[AlivcShortVideoRoute shared]registerMediaConfig:_quVideo];
        UIViewController *record = [[AlivcShortVideoRoute shared] alivcViewControllerWithType:AlivcViewControlRecord];
        [self.navigationController pushViewController:record animated:YES];
    }else {
        //合拍
//        AliyunCompositionViewController *targetVC = [[AliyunCompositionViewController alloc]init];
//        
//        _quVideo.videoOnly = YES;
////        _quVideo.minDuration = 2;
//        _quVideo.maxDuration = 31;
//        targetVC.compositionConfig = _quVideo;
//        targetVC.controllerType = AlivcCompositionViewControllerTypeVideoMix;
//        
//        [self.navigationController pushViewController:targetVC animated:YES];
    }
   
   
}


#pragma mark - setter & getter
- (void)setRecordType:(AlivcRecordType)recordType {
    _recordType = recordType;
    if (recordType == AlivcRecordTypeNormal) {
        [self.recordButton setTitle:@"开启录制界面" forState:0];
    } else {
        [self.recordButton setTitle:@"选择合拍视频" forState:0];
    }
}
@end
