//
//  AliyunMagicCameraViewController.m
//  AliyunVideoClient_Entrance
//
//  Created by wanghao on 2019/2/20.
//  Copyright © 2019年 Alibaba. All rights reserved.
//

#import "AliyunMagicCameraViewController.h"
#import <AliyunVideoSDKPro/AliyunIRecorder.h>
#import <CoreMotion/CoreMotion.h>

#import "AVC_ShortVideo_Config.h"
#import "AlivcDefine.h"
#import "AliyunPathManager.h"
#import "AlivcUIConfig.h"
#import "MBProgressHUD+AlivcHelper.h"
#import "AlivcShortVideoRoute.h"
#import "AliyunReachability.h"
//view
#import "AlivcRecordNavigationBar.h"
#import "QUProgressView.h"
#import "AlivcRecordBottomView.h"
#import "AlivcRecordTimerLable.h"
#import "AlivcRecordFocusView.h"
#import "AliyunMusicPickViewController.h"
#import "AlivcRecordSliderButtonsView.h"
//美颜
#if SDK_VERSION == SDK_VERSION_CUSTOM
#import "AlivcShortVideoFaceUnityManager.h"
#endif
#import "AlivcRecordBeautyView.h"
#import "AlivcWebViewController.h"
//动图
#import <AliyunVideoSDKPro/AliyunHttpClient.h>
#import "AliyunResourceManager.h"
#import "AliyunDownloadManager.h"
#import "AlivcRecordPasterView.h"
#import "AliyunMagicCameraEffectCell.h"
//滤镜
#import "AlivcBottomMenuFilterView.h"

#import "NSString+AlivcHelper.h"

#import <Photos/Photos.h>

@interface AliyunMagicCameraViewController ()<AliyunIRecorderDelegate,AlivcRecordBottomViewDelegate,
AlivcRecordNavigationBarDelegate,AliyunMusicPickViewControllerDelegate,
AlivcRecordSliderButtonsViewDelegate,AlivcRecordBeautyViewDelegate,
AlivcRecordPasterViewDelegate>
//SDK
@property (nonatomic, strong) AliyunIRecorder *recorder;        //录制
//system
@property (nonatomic, strong) CMMotionManager *motionManager;   //陀螺仪
//view
@property (nonatomic, strong) QUProgressView *progressView;                 //进度条
@property (nonatomic, strong) AlivcRecordNavigationBar *navigationBar;      //顶部导航栏
@property (nonatomic, strong) AlivcRecordSliderButtonsView *sliderButtonsView;  //侧边菜单栏
@property (nonatomic, strong) AlivcRecordBottomView *bottomView;        //底部view
@property (nonatomic, strong) AlivcRecordTimerLable *timerCountLab;     //倒计时lab
@property (nonatomic, strong) AlivcRecordBeautyView *beautyView;        //美颜view
@property (nonatomic, strong) AlivcRecordPasterView *pasterView;        //动图view
@property (nonatomic, strong) AlivcBottomMenuFilterView *filterView;    //滤镜view
@property (nonatomic, strong) AlivcRecordFocusView *focusView;          //聚焦框
//data
@property (nonatomic, strong) AliyunDownloadManager *downloadManager;   //下载管理（动图）
@property (nonatomic, strong) AliyunResourceManager *resourceManager;   //资源管理（动图）
@property (nonatomic, strong) NSMutableArray *allPasterInfoArray;       //所有动图资源
@property (nonatomic, strong) AliyunEffectPaster *currentEffectPaster;  //当前的人脸动图
@property (nonatomic, strong) AliyunReachability *reachability;         //网络监听

@property (nonatomic, assign) BOOL shouldStartPreviewWhenActive;    //跳转其他页面停止预览，返回开始预览，退后台进入前台则一直在预览。这2种情况通过此变量区别。

@property (nonatomic, assign) CGFloat recorderDuration; //本地记录的视频录制时长
@end

@implementation AliyunMagicCameraViewController
{
    NSInteger _cameraRotate; //相机旋转角度
    CGSize _outputSize;     //初始输出分辨率，此值切换画幅的时候用到
    NSInteger _musicTab;   //之前选中的音乐tab：本地、远程
    AliyunMusicPickModel *_currentMusic;//当前应用的音乐
//    BOOL _stopRecordActionUnfinished; //录制结束动作未完成，（有个场景需求是调用stopRecording和回调recorderDidStopRecording返回之间不响应录制按钮事件）
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.view.backgroundColor = [UIColor blackColor];
    //开启陀螺仪获取手机旋转角度
    [self startRetainCameraRotate];
    [self updateNavigationBarTorchModeStatus];
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];//录制模块禁止自动熄屏
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationNone];
    self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    if (self.shouldStartPreviewWhenActive) {
        [self.recorder startPreview];
        self.shouldStartPreviewWhenActive = NO;
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [self.motionManager stopDeviceMotionUpdates];
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationNone];
    //关闭闪光灯
    [self.recorder switchTorchWithMode:AliyunIRecorderTorchModeOff];
    [self updateNavigationBarTorchModeStatus];
    self.navigationController.interactivePopGestureRecognizer.enabled = YES;
}
- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [self settingQuietModePlaying];
}
-(void)settingQuietModePlaying{
    //手机静音，播放有声音
    AVAudioSession *avSession = [AVAudioSession sharedInstance];
    [avSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    [avSession setActive:YES error:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    //设置默认视频角度为
//    _cameraRotate =90;
    //VC布局
    [self setupSubviews];
    //添加通知
    [self addNotification];
    //开始预览
    [self.recorder startPreviewWithPositon:AliyunIRecorderCameraPositionFront];
    //设置默认美颜状态
    [self alivcRecordBeautyDidChangeBeautyType:self.beautyView.currentBeautyType];
    //添加手势
    [self addGesture];
    //开启网络监听
    [self startNetworkReachability];
    //默认值设置
    self.shouldStartPreviewWhenActive = NO;
    self.recorderDuration = 0;
}
- (void)setupSubviews{
    if (!_uiConfig) {
        _uiConfig =[[AlivcRecordUIConfig alloc]init];
    }
    self.view.backgroundColor = _uiConfig.backgroundColor;
    //添加倒计时lab
    [self.view addSubview:self.timerCountLab];
    //添加预览view
    [self.view addSubview:self.recorder.preview];
    //添加顶部录制进度条
    [self.view addSubview:self.progressView];
    //添加顶部导航条
    _navigationBar =[[AlivcRecordNavigationBar alloc]initWithUIConfig:_uiConfig];
    _navigationBar.delegate =self;
    [self.view addSubview:_navigationBar];
    //添加右侧菜单栏-baan
//    [self.view addSubview:self.sliderButtonsView];
    //添加底部view
    [self.view addSubview:self.bottomView];
    if (self.touchMode == AlivcRecordButtonTouchModeClick) {
        self.progressView.hidden = false;
        self.bottomView.rateSelectView.hidden = false;
    }else {
        self.progressView.hidden = true;
        self.bottomView.rateSelectView.hidden = true;
    }
    if (!self.finishBlock) {
        //隐藏照片,视频文字
        [self.bottomView.toolView hideMixButton];
    }
}
// 监听通知
- (void)addNotification
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDelete:) name:AliyunEffectResourceDeleteNotification object:nil];
}
- (void)startNetworkReachability{
    //网络状态判定
    _reachability = [AliyunReachability reachabilityForInternetConnection];
    [_reachability startNotifier];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachabilityChanged)
                                                 name:AliyunPVReachabilityChangedNotification
                                               object:nil];
}
// 资源被删除的通知
- (void)resourceDelete:(NSNotification *)noti{
    
}

- (void)appWillResignActive:(id)sender
{
    [self.recorder switchTorchWithMode:AliyunIRecorderTorchModeOff];
    [self.timerCountLab stopTimer];
    if (self.recorder.isRecording) {
        [self.recorder stopRecording];
    }
    [self updateViewsStatus];
}


- (void)appDidBecomeActive:(id)sender
{
    //刷新闪光灯按钮状态
    [self updateNavigationBarTorchModeStatus];
}

#pragma mark - 网络变化
//网络状态判定
- (void)reachabilityChanged{
    AliyunPVNetworkStatus status = [self.reachability currentReachabilityStatus];
    if (status != AliyunPVNetworkStatusNotReachable) {
        [self fetchData];
    }
}
//预览view的坐标大小计算
- (CGRect)previewFrame{
    CGFloat ratio =_quVideo.outputSize.width / _quVideo.outputSize.height;
    CGRect finalFrame = CGRectMake(0, NoStatusBarSafeTop+44+10, ScreenWidth, ScreenWidth /ratio);
    if ([_quVideo mediaRatio] == AliyunMediaRatio9To16){
        finalFrame =CGRectMake((ScreenWidth - ScreenHeight * ratio)/2.f , 0, ScreenHeight * ratio, ScreenHeight);
    }
    return finalFrame;
}
//更新UI状态
- (void)updateViewsStatus{
    //更新录制按钮下方的删除按钮状态
    [self.bottomView updateViewsWithVideoPartCount:[self partCount]];
    //更新录制时间
    [self.bottomView refreshRecorderVideoDuration:self.recorderDuration];
    //更新录制UI
    [self.bottomView updateRecorderUI];
    //更新导航栏完成按钮状态
    [self.navigationBar setFinishButtonEnabled:(self.recorderDuration >= [self finishButtonEnabledMinDuration])];
    //更新右侧按钮显示/隐藏状态
    [_navigationBar setHidden:(self.recorder.isRecording||self.timerCountLab.isTiming)];
    //更新定时录制按钮的可点击状态
    [_navigationBar setTimerButtonEnabled:(self.recorderDuration < [self maxDuration])];
    [self.sliderButtonsView setHidden:(self.recorder.isRecording||self.timerCountLab.isTiming)];
    //更新音乐按钮的可点击状态
    [self.sliderButtonsView setMusicButtonEnabled:(self.recorderDuration == 0)];
    //更新底部录制view
    [self.bottomView setHidden:self.timerCountLab.isTiming];
}
//更新闪光灯按钮状态
- (void)updateNavigationBarTorchModeStatus{
    if (self.recorder.cameraPosition == AliyunIRecorderCameraPositionFront) {//前置摄像头禁用闪光灯
        [self.navigationBar setTorchButtonImageWithMode:AlivcRecordTorchModeDisabled];
    }else{//后置摄像头
        [self.navigationBar setTorchButtonImageWithMode:(AlivcRecordTorchMode)self.recorder.torchMode];
    }
}

- (void)hiddenMusicButton {
    UIButton *musicButton = [self.sliderButtonsView viewWithTag:AlivcRecordSlidButtonTypeMusic];
    UIButton *filterButton = [self.sliderButtonsView viewWithTag:AlivcRecordSlidButtonTypeFilter];
    UIButton *switchRatioButton = [self.sliderButtonsView viewWithTag:AlivcRecordSlidButtonTypeSwitchRatio];
    musicButton.hidden = YES;
    switchRatioButton.hidden = YES;
    filterButton.frame = musicButton.frame;
}
- (CGFloat)finishButtonEnabledMinDuration {
    return _quVideo.minDuration;
}
#pragma mark - GET
- (AliyunIRecorder *)recorder{
    if (!_recorder) {
        //清除之前生成的录制路径
        NSString *recordDir = [AliyunPathManager createRecrodDir];
        [AliyunPathManager clearDir:recordDir];
        //生成这次的存储路径
        NSString *taskPath = [recordDir stringByAppendingPathComponent:[AliyunPathManager randomString]];
        //视频存储路径
        NSString *videoSavePath = [[taskPath stringByAppendingPathComponent:[AliyunPathManager randomString]] stringByAppendingPathExtension:@"mp4"];
        _recorder =[[AliyunIRecorder alloc] initWithDelegate:self videoSize:_quVideo.outputSize];
        _recorder.preview = [[UIView alloc]initWithFrame:[self previewFrame]];
        _recorder.outputType = AliyunIRecorderVideoOutputPixelFormatType420f;//SDK自带人脸识别只支持YUV格式
        _recorder.useFaceDetect = YES;
        _recorder.faceDetectCount = 2;
        _recorder.faceDectectSync = NO;
        _recorder.frontCaptureSessionPreset = AVCaptureSessionPreset1280x720;
        _recorder.encodeMode = (_quVideo.encodeMode == AliyunEncodeModeSoftFFmpeg)?0:1;
        NSLog(@"录制编码方式：%d",_recorder.encodeMode);
        _recorder.GOP = _quVideo.gop;
        _recorder.videoQuality = (AliyunVideoQuality)_quVideo.videoQuality;
        _recorder.recordFps = _quVideo.fps;
        _recorder.outputPath = _quVideo.outputPath?_quVideo.outputPath:videoSavePath;
        _quVideo.outputPath = _recorder.outputPath;
        _recorder.taskPath = taskPath;
        _recorder.beautifyStatus = YES;
        //录制片段设置
//        _recorder.clipManager.maxDuration = _quVideo.maxDuration;
        [self recorder:_recorder setMaxDuration:_quVideo.maxDuration];
//        _recorder.clipManager.minDuration = _quVideo.minDuration;
        [self recorder:_recorder setMinDuration:_quVideo.minDuration];
    }
    return _recorder;
}

- (QUProgressView *)progressView{
    if (!_progressView) {
        _progressView =[[QUProgressView alloc] initWithFrame:CGRectMake(8, NoStatusBarSafeTop+4, ScreenWidth-16, 4)];
        _progressView.showBlink = NO;
        _progressView.showNoticePoint = YES;
        _progressView.layer.cornerRadius = CGRectGetHeight(_progressView.frame)/2;
        _progressView.layer.masksToBounds =YES;
        _progressView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.34];
        _progressView.colorProgress = [UIColor colorWithHexString:@"0xFC4448"];
        _progressView.maxDuration = _quVideo.maxDuration;
        _progressView.minDuration = _quVideo.minDuration;
    }
    return _progressView;
}
- (AlivcRecordBottomView *)bottomView{
    if (!_bottomView) {
        _bottomView =[[AlivcRecordBottomView alloc] initWithFrame:CGRectMake(0, ScreenHeight-185-SafeBottom, ScreenWidth, 200) withUIConfig:self.uiConfig withTouchMode:_touchMode];
        _bottomView.delegate =self;
    }
    return _bottomView;
}
- (AlivcRecordSliderButtonsView *)sliderButtonsView{
    if (!_sliderButtonsView) {
        _sliderButtonsView =[[AlivcRecordSliderButtonsView alloc] initWithFrame:CGRectMake(ScreenWidth - 52 -10, CGRectGetMaxY(self.navigationBar.frame)+40, 52, 200)];
        _sliderButtonsView.delegate = self;
    }
    return _sliderButtonsView;
}
- (UILabel *)timerCountLab{
    if (!_timerCountLab) {
        _timerCountLab =[[AlivcRecordTimerLable alloc]initWithFrame:self.view.bounds];
    }
    return _timerCountLab;
}
- (AlivcRecordBeautyView *)beautyView{
    if (!_beautyView) {
        AlivcBottomMenuHeaderViewItem *item1 =[AlivcBottomMenuHeaderViewItem createItemWithTitle:[@"美颜" localString] icon:[UIImage imageNamed:@"AlivcIconBeauty"] tag:1];
        AlivcBottomMenuHeaderViewItem *item2 =[AlivcBottomMenuHeaderViewItem createItemWithTitle:[@"美肌" localString] icon:[AlivcImage imageNamed:@"shortVideo_beautySkin"] tag:2];
        CGFloat safeTop = 78;
        _beautyView =[[AlivcRecordBeautyView alloc]initWithFrame:CGRectMake(0, ScreenHeight-200-safeTop, ScreenWidth, 200+safeTop) withItems:@[item1,item2]];
        _beautyView.safeTop = safeTop;
        _beautyView.showHeaderViewSelectedFlag = YES;
        _beautyView.delegate = self;
        [self.view addSubview:_beautyView];
    }
    return _beautyView;
}
- (AlivcRecordPasterView *)pasterView{
    if (!_pasterView) {
        AlivcBottomMenuHeaderViewItem *item1 =[AlivcBottomMenuHeaderViewItem createItemWithTitle:[@"人脸贴纸" localString] icon:[AlivcImage imageNamed:@"shortVideo_paster_gif"] tag:1];
        _pasterView = [[AlivcRecordPasterView alloc]initWithFrame:CGRectMake(0, ScreenHeight-200, ScreenWidth, 200) withItems:@[item1]];
        _pasterView.delegate = self;
        [self.view addSubview:_pasterView];
        [self fetchData];
    }
    return _pasterView;
}


- (AlivcBottomMenuFilterView *)filterView{
    if (!_filterView) {
        AlivcBottomMenuHeaderViewItem *item1 =[AlivcBottomMenuHeaderViewItem createItemWithTitle:[@"滤镜" localString] icon:[AlivcImage imageNamed:@"alivc_svEdit_filter"] tag:1];
        _filterView = [[AlivcBottomMenuFilterView alloc]initWithFrame:CGRectMake(0, ScreenHeight-200, ScreenWidth, 200) withItems:@[item1]];
        [self.view addSubview:_filterView];
        __weak typeof(self)weakSelf = self;
        [_filterView registerDidSelectEffectFilterBlock:^(AliyunEffectFilterInfo * _Nonnull filterInfo) {
            AliyunEffectFilter *effectFilter =[[AliyunEffectFilter alloc] initWithFile:[filterInfo localFilterResourcePath]];
            NSLog(@"vvvv effectfilter2:%@", effectFilter.path);
            [weakSelf.recorder applyFilter:effectFilter];
        }];
    }
    return _filterView;
}
- (AlivcRecordFocusView *)focusView{
    if (!_focusView) {
        CGFloat size = 150;
        _focusView =[[AlivcRecordFocusView alloc]initWithFrame:CGRectMake(0, 0, size, size)];
        _focusView.animation =YES;
        [self.recorder.preview addSubview:_focusView];
    }
    return _focusView;
}

- (NSMutableArray *)allPasterInfoArray{
    if (!_allPasterInfoArray) {
        _allPasterInfoArray = [NSMutableArray arrayWithCapacity:10];
    }
    return _allPasterInfoArray;
}
- (AliyunDownloadManager *)downloadManager{
    if (!_downloadManager) {
        _downloadManager = [[AliyunDownloadManager alloc] init];
    }
    return _downloadManager;
}
- (AliyunResourceManager *)resourceManager{
    if (!_resourceManager) {
        _resourceManager = [[AliyunResourceManager alloc] init];
    }
    return _resourceManager;
}
#pragma mark - SET
- (void)setQuVideo:(AliyunMediaConfig *)quVideo{
    //需要copy一份，不然录制模块的参数改动会保存到配置页面
    _quVideo = [quVideo copy];
    _outputSize = _quVideo.outputSize;
}
#pragma mark - AlivcRecordNavigationBarDelegate -
- (void)alivcRecordNavigationBarButtonActionType:(AlivcRecordNavigationBarType)type{
    switch (type) {
        case AlivcRecordNavigationBarTypeGoback://返回
        {
            [self.recorder stopPreview];
            #if SDK_VERSION == SDK_VERSION_CUSTOM
//            [[AlivcShortVideoFaceUnityManager shareManager] destoryItems];
            #endif
            [self backToFlutter];
            
        }
            break;
        case AlivcRecordNavigationBarTypeCameraSwitch://切换摄像头
        {
            if (![self checkAVAuthorizationStatus]) {
                return;
            }
            [self.recorder switchCameraPosition];
            [self updateNavigationBarTorchModeStatus];
        }
            break;
        case AlivcRecordNavigationBarTypeTiming://定时拍摄
        {
            if (![self checkAVAuthorizationStatus]) {
                return;
            }
            __weak typeof(self)weakSelf =self;
            [self.timerCountLab startTimerWithComplete:^{
                [weakSelf.recorder startRecording];
                [weakSelf updateViewsStatus];
                NSLog(@"倒计时结束");
            }];
            [self updateViewsStatus];
        }
            break;
        case AlivcRecordNavigationBarTypeFlashMode://闪光灯
        {
            [self.recorder switchTorchWithMode:!self.recorder.torchMode];
            [self updateNavigationBarTorchModeStatus];
        }
            break;
        case AlivcRecordNavigationBarTypeFinish://完成
        {
            if(self.isMixedViedo) {
                [self recorderDidFinishRecording];
            }else{
                 [self.recorder finishRecording];
            }
          
        }
            break;
        default:
            break;
    }
}
#pragma mark - AlivcRecordSlidButtonsViewDelegate -
- (void)alivcRecordSlidButtonAction:(AlivcRecordSlidButtonType)type{
    if (type == AlivcRecordSlidButtonTypeFilter) {
        [self.filterView show];
    }else if (type == AlivcRecordSlidButtonTypeMusic){
        AliyunMusicPickViewController *vc =[[AliyunMusicPickViewController alloc] init];
        vc.delegate = self;
        vc.duration = _quVideo.maxDuration; 
        [vc setSelectedMusic:_currentMusic type:_musicTab];
        [self.recorder stopPreview];
        self.shouldStartPreviewWhenActive = YES;
        [self.navigationController pushViewController:vc animated:YES];
    }else if (type == AlivcRecordSlidButtonTypeSwitchRatio){
        [self switchRatio];
    }else{
        NSLog(@"#Warning:对应的type没做实现");
    }
}
//切换画幅
- (void)switchRatio{
    [self.sliderButtonsView setSwitchRationButtonEnabled:NO];
    [self updateNavigationBarTorchModeStatus];
    _quVideo.videoRotate = 0;//初始化为0度
    switch ([_quVideo mediaRatio]) {
        case AliyunMediaRatio9To16:
            _quVideo.outputSize = CGSizeMake(_outputSize.width, _outputSize.width*4.0/3);
            break;
        case AliyunMediaRatio3To4:
            _quVideo.outputSize = CGSizeMake(_outputSize.width, _outputSize.width);
            break;
        case AliyunMediaRatio1To1:
            _quVideo.outputSize =  CGSizeMake(_outputSize.width, _outputSize.width*16.0/9);
            break;
        default:break;
    }
    
    [self.recorder reStartPreviewWithVideoSize:[_quVideo fixedSize]];
    [UIView animateWithDuration:0.3 animations:^{
        self.recorder.preview.frame = [self previewFrame];

    } completion:^(BOOL finished) {
    }];
}

#pragma mark - AlivcRecordBottomViewDelegate -
- (void)didSelectMusic:(AliyunMusicPickModel *)music tab:(NSInteger)tab{
    _musicTab = tab;
    _currentMusic = music;
    if ([music.name isEqualToString:@"无音乐"] || !music.path || ![[NSFileManager defaultManager] fileExistsAtPath:music.path]) {
        //清除音乐效果
        [self.recorder applyMusic:nil];
    }else{
        AliyunEffectMusic *effectMusic = [[AliyunEffectMusic alloc] initWithFile:music.path];
        effectMusic.startTime = music.startTime / 1000.0f;
        effectMusic.duration = music.duration;
        //添加音乐
        [self.recorder applyMusic:effectMusic];
        NSLog(@"%@",effectMusic.path);
        NSLog(@"----------->:有path，有文件");
    }
    
    [self.sliderButtonsView updateMusicCoverWithUrl:music.image];
}
- (void)alivcRecordBottomViewDidSelectRate:(CGFloat)rate{
    NSLog(@"速度:%f",rate);
    [self.recorder setRate:rate];
}
- (void)alivcRecordBottomViewDeleteVideoPart{
    [self deletePart];
    self.progressView.videoCount = [self partCount];
    self.recorderDuration =[self duration];
    [self.progressView updateProgress:[self duration]];
    [self updateViewsStatus];
}

- (void)alivcRecordBottomViewChangeTouchMode:(AlivcRecordButtonTouchMode *)mode {
    self.touchMode = mode;
    if (mode == AlivcRecordButtonTouchModeClick) {
        self.progressView.hidden = false;
        self.bottomView.rateSelectView.hidden = false;
        self.bottomView.recordButttonView.timeLab.hidden = false;
    }else {
        self.progressView.hidden = true;
        self.bottomView.rateSelectView.hidden = true;
        self.bottomView.recordButttonView.timeLab.hidden = true;
    }
}

- (BOOL)alivcRecordBottomViewStartRecord{
//    if (_stopRecordActionUnfinished) {
//        NSLog(@"有停止录制动作未完成");
//        return NO;
//    }
    
    NSLog(@"tooooooouch:%ld",self.bottomView.toolView.touchMode);
    if (![self checkAVAuthorizationStatus]) {
        return NO;
    }
    
    AlivcRecordButtonTouchMode mode = self.bottomView.toolView.touchMode;
    if (mode == AlivcRecordButtonTouchModeClick){
       if ([self partCount]<=0) {
    
           self.recorder.cameraRotate = (int)_cameraRotate;
           _quVideo.videoRotate = self.recorder.cameraRotate;
    
       }
       if ([self.recorder startRecording] == 0) {
           [self updateViewsStatus];
           return YES;
       }else{
           return NO;
       }
    }else {
        __weak typeof(self)weakSelf = self;
        [self.recorder takePhoto:^(UIImage *image, UIImage *rawImage) {
            NSLog(@"iiiiiimage%@", image);
            [[weakSelf class] srh_saveImage:image completionHandle:^(NSError *error, NSString *localId) {
                if (localId == nil) {return;};
                PHFetchResult* assetResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[localId] options:nil];
                PHAsset *asset = [assetResult firstObject];
//                [[PHImageManager defaultManager] requestImageDataForAsset:asset
//                                                                  options:nil
//                                                            resultHandler:^(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info) {
//                    NSURL *fileUrl = [info objectForKey:@"PHImageFileURLKey"];
//                    if (fileUrl) {
//                        NSLog(@"Image path: %@", [fileUrl relativePath]);
//                        NSString *path = [fileUrl relativePath];
//                        if (weakSelf.finishBlock) {
//                            weakSelf.finishBlock(path);
//                            [weakSelf backToFlutter];
//                        }
//                    } else {
//                        NSLog(@"Error retrieving image filePath, heres whats available: %@", info);
//                    }
//                }];
                
                PHContentEditingInputRequestOptions *editOptions = [[PHContentEditingInputRequestOptions alloc] init];
                [asset requestContentEditingInputWithOptions:editOptions completionHandler:^(PHContentEditingInput *contentEditingInput, NSDictionary *info) {

                    if (contentEditingInput.fullSizeImageURL) {
                        NSString *path = [contentEditingInput.fullSizeImageURL relativePath];
                        if (weakSelf.finishBlock) {
                            NSString *type = [NSString stringWithFormat:@"%ld", weakSelf.touchMode];
                            NSDictionary *dict = @{@"filePath":path, @"fileType": type};
                            weakSelf.finishBlock(dict);
                            [weakSelf backToFlutter];
                        }
                    }

                }];
            }];
        }];
        return YES;
    }
}
 
- (void)alivcRecordBottomViewStopRecord{
//    _stopRecordActionUnfinished =YES;
    [self.recorder stopRecording];
    //刷新界面
    [self updateViewsStatus];
}
- (BOOL)alivcRecordBottomViewIsRecording{
    return self.recorder.isRecording;
}
- (void)alivcRecordBottomViewBeautyButtonOnclick{
    [self.beautyView show];
}
- (void)alivcRecordBottomViewEffectButtonOnclick{
    [self.pasterView show];
}
//检测权限
-(BOOL)checkAVAuthorizationStatus{
    for (AVMediaType mediaType in @[AVMediaTypeVideo,AVMediaTypeAudio]) {
        if ([AVCaptureDevice authorizationStatusForMediaType:mediaType] != AVAuthorizationStatusAuthorized) {
            [self showAVAuthorizationAlertWithMediaType:mediaType];
            return NO;
        }
    }
    return YES;
}
//显示一个权限弹窗
-(void)showAVAuthorizationAlertWithMediaType:(AVMediaType)mediaType{
    NSString *title =[@"打开相机失败" localString];
    NSString *message =[@"摄像头无权限" localString];
    if (mediaType == AVMediaTypeAudio) {
        title = [@"获取麦克风权限失败" localString];
        message =[@"麦克风无权限" localString];
    }
    UIAlertController *alertController =[UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *action1 =[UIAlertAction actionWithTitle:[@"取消" localString] style:UIAlertActionStyleDestructive handler:nil];
    UIAlertAction *action2 =[UIAlertAction actionWithTitle:[@"设置" localString] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [[UIApplication sharedApplication]openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
    }];
    [alertController addAction:action1];
    [alertController addAction:action2];
    [self presentViewController:alertController animated:NO completion:nil];
}


#pragma mark - 美颜 -
#pragma mark - AlivcRecordBeautyViewDelegate
- (void)alivcRecordBeautyDidChangeBeautyType:(AlivcBeautySettingViewStyle)type{
    if (type == AlivcBeautySettingViewStyle_ShortVideo_BeautyFace_Base) {
        self.recorder.beautifyStatus = YES;
        self.recorder.beautifyValue = (int)self.beautyView.currentBaseBeautyLevel*20;
    }else{
        self.recorder.beautifyStatus = NO;
        self.recorder.beautifyValue = 0;
    }
}
- (void)alivcRecordBeautyDidChangeBaseBeautyLevel:(NSInteger)level{
    self.recorder.beautifyValue = (int)level*20;
}
- (void)alivcRecordBeautyDidSelectedGetFaceUnityLink{
    AlivcWebViewController *introduceC = [[AlivcWebViewController alloc] initWithUrl:kIntroduceUrl title:NSLocalizedString(@"Third-party capability acquisition instructions", nil)];
    [self.navigationController pushViewController:introduceC animated:YES];
}

#pragma mark - AliyunIRecorderDelegate -
// 设备权限
- (void)recorderDeviceAuthorization:(AliyunIRecorderDeviceAuthor)status {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (status == AliyunIRecorderDeviceAuthorAudioDenied) {
            [self showAVAuthorizationAlertWithMediaType:AVMediaTypeAudio];
        } else if (status == AliyunIRecorderDeviceAuthorVideoDenied) {
            [self showAVAuthorizationAlertWithMediaType:AVMediaTypeVideo];
        }
        //当权限有问题的时候，不会走startPreview，所以这里需要更新下UI
        [self.sliderButtonsView setSwitchRationButtonEnabled:(self.recorderDuration == 0)];
    });
}
// 录制进度
- (void)recorderVideoDuration:(CGFloat)duration{
    NSLog(@"录制中：%f",duration);
    [self.progressView updateProgress:duration];
    [self.bottomView refreshRecorderVideoDuration:duration];
    self.recorderDuration = duration;
}
// 录制停止
- (void)recorderDidStopRecording{
    NSLog(@"----停止录制");
//    _stopRecordActionUnfinished =NO;
    _progressView.videoCount = [self partCount];
    //更新录制按钮下方的删除按钮状态
    [self.bottomView updateViewsWithVideoPartCount:[self partCount]];
}

- (void)recorderDidFinishRecording{
    NSLog(@"----完成录制");
//    UISaveVideoAtPathToSavedPhotosAlbum(_recorder.outputPath, self, nil, nil);
    [self updateViewsStatus];
    //停止预览
    [self.recorder stopPreview];
    self.shouldStartPreviewWhenActive = YES;
    //跳转处理
    NSString *outputPath = self.recorder.outputPath;
    if (self.finishBlock) {
        NSString *type = [NSString stringWithFormat:@"%ld", self.touchMode];
        NSDictionary *dict = @{@"filePath":outputPath, @"fileType": type};
        self.finishBlock(dict);
        [self backToFlutter];
    }else{
        [[AlivcShortVideoRoute shared]registerEditVideoPath:outputPath];
        [[AlivcShortVideoRoute shared]registerEditMediasPath:nil];
        [[AlivcShortVideoRoute shared]registerMediaConfig:_quVideo];
        if(_currentMusic && ![_currentMusic.name isEqualToString:@"无音乐"]){
            [[AlivcShortVideoRoute shared] registerHasRecordMusic:YES];
        }else{
            [[AlivcShortVideoRoute shared] registerHasRecordMusic:NO];
        }
        [[AlivcShortVideoRoute shared] registerIsMixedVideo:self.isMixedViedo];
        UIViewController *editVC = [[AlivcShortVideoRoute shared]alivcViewControllerWithType:AlivcViewControlEdit];
        //baan
        [self.navigationController pushViewController:editVC animated:YES];
    }
    [MBProgressHUD hideHUDForView:self.view animated:YES];
}

//当录至最大时长时回调
- (void)recorderDidStopWithMaxDuration{
    NSLog(@"录制到最大时长");
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    [self.recorder finishRecording];
}
- (void)recorderDidStartPreview{
    [self.sliderButtonsView setSwitchRationButtonEnabled:(self.recorderDuration == 0)];
    NSLog(@"-------->开始预览");
}
// 录制异常
- (void)recoderError:(NSError *)error {
    NSLog(@"recoderError%@",error);
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    [MBProgressHUD showWarningMessage:[NSString stringWithFormat:@"录制异常：%@",error.localizedDescription] inView:self.view];
    [self updateViewsStatus];
}
// 集成faceunity
#if SDK_VERSION == SDK_VERSION_CUSTOM
//- (CVPixelBufferRef)customRenderedPixelBufferWithRawSampleBuffer:(CMSampleBufferRef)sampleBuffer {
//    if (self.beautyView.currentBeautyType == AlivcBeautySettingViewStyle_ShortVideo_BeautyFace_Base) {
//        return CMSampleBufferGetImageBuffer(sampleBuffer);
//    }
//    //注意这里美颜美肌的参数是分开的beautyParams和beautySkinParams
//    //美颜参数设置(这里用的是beautyParams)
//    CGFloat beautyWhite = self.beautyView.beautyParams.beautyWhite;
//    CGFloat beautyBuffing = self.beautyView.beautyParams.beautyBuffing;
//    CGFloat beautyRuddy = self.beautyView.beautyParams.beautyRuddy;
//    //美肌参数设置(这里用的是beautySkinParams)
//    CGFloat beautyBigEye = self.beautyView.beautySkinParams.beautyBigEye;
//    CGFloat beautySlimFace = self.beautyView.beautySkinParams.beautySlimFace;
//
//    CVPixelBufferRef buf = [[AlivcShortVideoFaceUnityManager shareManager] RenderedPixelBufferWithRawSampleBuffer:sampleBuffer beautyWhiteValue:beautyWhite/100.0 blurValue:beautyBuffing/100.0 bigEyeValue:beautyBigEye/100.0 slimFaceValue:beautySlimFace/100.0 buddyValue:beautyRuddy/100.0];
//    return buf;
//}
#endif

#pragma mark - 动图数据相关 -
// 动图数据请求 + ui更新
- (void)fetchData
{
    [self.allPasterInfoArray removeAllObjects];
    AliyunHttpClient *httpClient = [[AliyunHttpClient alloc] initWithBaseUrl:kAlivcQuUrlString];
    NSDictionary *param = @{@"type":@(1)};
    __weak typeof(self)weakSelf = self;
    [httpClient GET:@"resource/getFrontPasterList" parameters:param completionHandler:^(NSURLResponse *response, id responseObject, NSError *error) {
        if (error) {
            NSArray *groups = [self loadLocalData];
            if (self.allPasterInfoArray.count>0) {
                [self.allPasterInfoArray removeAllObjects];
            }
            if (groups.count > 0) {
                for (AliyunPasterInfoGroup *pasterInfoGroup in groups) {
                    [self.allPasterInfoArray addObjectsFromArray:pasterInfoGroup.pasterList];
                }
            }
            [weakSelf.pasterView refreshUIWithGifItems:weakSelf.allPasterInfoArray];
            return ;
        }
        NSArray *pastList = responseObject[@"data"];
        for (NSDictionary *dict in pastList) {
            AliyunPasterInfo *info = [[AliyunPasterInfo alloc] initWithDict:dict];
            [self.allPasterInfoArray addObject:info];
        }
        [weakSelf.pasterView refreshUIWithGifItems:weakSelf.allPasterInfoArray];
    }];
}
//本地的动图资源
- (NSArray *)loadLocalData
{
    return [self.resourceManager loadLocalFacePasters];
}

//点击动图回调
- (void)alivcRecordPasterViewDidSelectedPasterInfo:(AliyunPasterInfo *)pasterInfo cell:(UICollectionViewCell *)cell{
    if (pasterInfo.eid <= 0 || [pasterInfo.bundlePath isEqualToString:@"icon"]) {//remove
        [self deleteCurrentEffectPaster];
        [self.pasterView refreshUIWhenThePasterInfoApplyedWithPasterInfo:pasterInfo];
        return;
    }
    //new
    [self deleteCurrentEffectPaster]; //delete pre
    if (pasterInfo.bundlePath != nil) {
        [self addEffectWithPasterInfo:pasterInfo path:pasterInfo.bundlePath];
        return;
    }
    if (![pasterInfo fileExist]) {
        cell.userInteractionEnabled = NO;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            //防止下载异常导致cell不能响应事件
            cell.userInteractionEnabled = YES;
        });
        AliyunDownloadTask *task = [[AliyunDownloadTask alloc] initWithInfo:pasterInfo];
        [self.downloadManager addTask:task];
        AliyunMagicCameraEffectCell *effectCell = (AliyunMagicCameraEffectCell *)cell;
        [effectCell shouldDownload:NO];
        task.progressBlock = ^(NSProgress *progress) {
            CGFloat pgs = progress.completedUnitCount * 1.0 / progress.totalUnitCount;
            [effectCell downloadProgress:pgs];
        };
        __weak typeof(self) weakSelf = self;
        task.completionHandler = ^(NSString *path, NSError *err) {
            dispatch_async(dispatch_get_main_queue(), ^{
                cell.userInteractionEnabled = YES;
                effectCell.isLoading = NO;
                if (err) {
                    AliyunMagicCameraEffectCell *magicCell = (AliyunMagicCameraEffectCell *)cell;
                    [effectCell shouldDownload:YES];
                    magicCell.downloadImageView.image = [AlivcImage imageNamed:@"shortVideo_downloadFailed"];
                    [MBProgressHUD showMessage:NSLocalizedString(@"网络不给力" , nil) inView:self.view];
                }else{
                    [weakSelf addEffectWithPasterInfo:pasterInfo path:path];
                    NSLog(@"");
                }
            });
        };
    } else {
        [self addEffectWithPasterInfo:pasterInfo path:[pasterInfo filePath]];
    }
}
/**
 删除当前的动图
 */
- (void)deleteCurrentEffectPaster
{
    if (_currentEffectPaster) {
        [self.recorder deletePaster:_currentEffectPaster];
        NSLog(@"动图测试：删除动图：%@\n",_currentEffectPaster.path);
        _currentEffectPaster = nil;
    }
}
/**
 应用新的动图特效
 @param info 动图对应的模型类
 @param path 此动图对应的路径
 */
- (void)addEffectWithPasterInfo:(AliyunPasterInfo *)info path:(NSString *)path
{
    if(self.recorder.isRecording){
        NSLog(@"动图测试:添加动图：录制中，不添加");
        return;
    }
 
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL result = [fileManager fileExistsAtPath:path];
    if(result) {
        [self deleteCurrentEffectPaster];
        AliyunEffectPaster *paster = [[AliyunEffectPaster alloc] initWithFile:path];
        [self.recorder applyPaster:paster];
        _currentEffectPaster = paster;
        [_pasterView refreshUIWhenThePasterInfoApplyedWithPasterInfo:info];
    }
}
//添加手势
- (void)addGesture
{
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapToFocusPoint:)];
    [self.recorder.preview addGestureRecognizer:tapGesture];
    UIPinchGestureRecognizer *pinchGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinchGesture:)];
    [self.recorder.preview addGestureRecognizer:pinchGesture];
}
//点按手势的触发方法
- (void)tapToFocusPoint:(UITapGestureRecognizer *)tapGesture {
    UIView *tapView = tapGesture.view;
    CGPoint point = [tapGesture locationInView:tapView];
    self.recorder.focusPoint = point;
    self.focusView.center = point;
    [self.recorder.preview bringSubviewToFront:self.focusView];
//    if (!self.recorder.isRecording) {
//        [self.magicCameraView cancelRecordBeautyView];
//    }
}
//捏合手势的触发方法
- (void)pinchGesture:(UIPinchGestureRecognizer *)pinchGesture {
    if (isnan(pinchGesture.velocity) || pinchGesture.numberOfTouches != 2) {
        return;
    }
    self.recorder.videoZoomFactor = pinchGesture.velocity;
    pinchGesture.scale = 1;
    return;
}
- (void)startRetainCameraRotate {
    //初始化全局管理对象
    if (!self.motionManager) {
        self.motionManager = [[CMMotionManager alloc] init];
    }
    if ([self.motionManager isDeviceMotionAvailable]) {
        self.motionManager.deviceMotionUpdateInterval =1;
        [self.motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMDeviceMotion * _Nullable motion, NSError * _Nullable error) {
            // Gravity 获取手机的重力值在各个方向上的分量，根据这个就可以获得手机的空间位置，倾斜角度等
            double gravityX = motion.gravity.x;
            double gravityY = motion.gravity.y;
            double xyTheta = atan2(gravityX,gravityY)/M_PI*180.0;//手机旋转角度。
            if (xyTheta >= -45 && xyTheta <= 45) {//down
                _cameraRotate =180;
            } else if (xyTheta > 45 && xyTheta < 135) {//left
                _cameraRotate = 90;
            } else if ((xyTheta >= 135 && xyTheta < 180) || (xyTheta >= -180 && xyTheta < -135)) {//up
                _cameraRotate = 0;
            } else if (xyTheta >= -135 && xyTheta < -45) {//right
                _cameraRotate = 270;
            }
            //            NSLog(@"手机旋转的角度为 --- %d", _cameraRotate);
        }];
    }
}

#pragma mark - 设备旋转
- (BOOL)shouldAutorotate
{
    return YES;
}
// 竖屏显示
- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}
- (void)dealloc
{
    NSLog(@"~~~~~~%s delloc", __PRETTY_FUNCTION__);
    [self.recorder stopPreview];
    [self.recorder destroyRecorder];
    _recorder = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
#if SDK_VERSION == SDK_VERSION_CUSTOM

//    [[AlivcShortVideoFaceUnityManager shareManager] destoryItems];baan
#endif
}

- (NSInteger)partCount {
    return self.recorder.clipManager.partCount;
}

- (CGFloat)duration {
    return self.recorder.clipManager.duration;
//    return self.recorderDuration;
}

- (void)deletePart {
    [self.recorder.clipManager deletePart];
}

- (void)recorder:(AliyunIRecorder *)recorder setMaxDuration:(CGFloat)maxDuration {
    recorder.clipManager.maxDuration = maxDuration;
}
- (CGFloat)maxDuration {
    return self.recorder.clipManager.maxDuration;
}

- (void)recorder:(AliyunIRecorder *)recorder setMinDuration:(CGFloat)minDuration {
    recorder.clipManager.minDuration = minDuration;
}

- (void)backToFlutter {
    if (![self.navigationController popViewControllerAnimated:YES]) {
        [self dismissViewControllerAnimated:YES completion:^{
            
        }];
    }

}

+ (void)srh_saveImage:(UIImage *)image completionHandle:(void (^)(NSError *, NSString *))completionHandler {
    // 1. 获取照片库对象
    PHPhotoLibrary *library = [PHPhotoLibrary sharedPhotoLibrary];
    
    // 假如外面需要这个 localIdentifier ，可以通过block传出去
    __block NSString *localIdentifier = @"";
    
    // 2. 调用changeblock
    [library performChanges:^{
        
        // 2.1 创建一个相册变动请求
        PHAssetCollectionChangeRequest *collectionRequest = [self getCurrentPhotoCollectionWithAlbumName:@"Timerec"];
        
        // 2.2 根据传入的照片，创建照片变动请求
        PHAssetChangeRequest *assetRequest = [PHAssetChangeRequest creationRequestForAssetFromImage:image];
        
        // 2.3 创建一个占位对象
        PHObjectPlaceholder *placeholder = [assetRequest placeholderForCreatedAsset];
        localIdentifier = placeholder.localIdentifier;
        
        // 2.4 将占位对象添加到相册请求中
        [collectionRequest addAssets:@[placeholder]];
        
    } completionHandler:^(BOOL success, NSError * _Nullable error) {
        
        if (error) {
            completionHandler(error, nil);
        } else {
            completionHandler(nil, localIdentifier);
        }
    }];
}

+ (PHAssetCollectionChangeRequest *)getCurrentPhotoCollectionWithAlbumName:(NSString *)albumName {
    // 1. 创建搜索集合
    PHFetchResult *result = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAlbumRegular options:nil];
    
    // 2. 遍历搜索集合并取出对应的相册，返回当前的相册changeRequest
    for (PHAssetCollection *assetCollection in result) {
        if ([assetCollection.localizedTitle containsString:albumName]) {
            PHAssetCollectionChangeRequest *collectionRuquest = [PHAssetCollectionChangeRequest changeRequestForAssetCollection:assetCollection];
            return collectionRuquest;
        }
    }
    
    // 3. 如果不存在，创建一个名字为albumName的相册changeRequest
    PHAssetCollectionChangeRequest *collectionRequest = [PHAssetCollectionChangeRequest creationRequestForAssetCollectionWithTitle:albumName];
    return collectionRequest;
}

@end
