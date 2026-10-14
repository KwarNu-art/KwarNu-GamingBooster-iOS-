#import <Foundation/Foundation.h>  
#import <UIKit/UIKit.h>  
#import <QuartzCore/QuartzCore.h>  
#import <mach/mach.h>  
#import <objc/runtime.h>  
  
#pragma clang diagnostic push  
#pragma clang diagnostic ignored "-Wdeprecated-declarations"  
  
@interface KwarNuBoosterOverlay : NSObject  
  
+ (instancetype)sharedInstance;  
- (void)showOverlay;  
  
@property (nonatomic, strong) UIWindow *overlayWindow;  
@property (nonatomic, strong) UIView *floatingButton;  
@property (nonatomic, strong) UIView *dashboardPanel;  
@property (nonatomic, strong) CADisplayLink *displayLink;  
  
// UI Metric Labels  
@property (nonatomic, strong) UILabel *fpsLabel;  
@property (nonatomic, strong) UILabel *ramLabel;  
@property (nonatomic, strong) UILabel *batteryLabel;  
@property (nonatomic, strong) UILabel *thermalLabel;  
  
// States  
@property (nonatomic, assign) NSInteger targetFPS;  
@property (nonatomic, assign) BOOL isBatterySaverActive;  
@property (nonatomic, assign) BOOL isPerformanceModeActive;  
  
@end  
  
@implementation KwarNuBoosterOverlay {  
    CFTimeInterval _lastTimestamp;  
    NSUInteger _frameCount;  
    CGFloat _currentFPS;  
}  
  
+ (instancetype)sharedInstance {  
    static KwarNuBoosterOverlay *instance = nil;  
    static dispatch_once_t onceToken;  
    dispatch_once(&onceToken, ^{  
        instance = [[self alloc] init];  
    });  
    return instance;  
}  
  
- (instancetype)init {  
    self = [super init];  
    if (self) {  
        _targetFPS = 60;  
        _isBatterySaverActive = NO;  
        _isPerformanceModeActive = NO;  
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;  
    }  
    return self;  
}  
  
- (void)showOverlay {  
    dispatch_async(dispatch_get_main_queue(), ^{  
        if (self.overlayWindow) return;  
  
        CGRect screenBounds = [UIScreen mainScreen].bounds;  
        self.overlayWindow = [[UIWindow alloc] initWithFrame:screenBounds];  
        self.overlayWindow.windowLevel = UIWindowLevelStatusBar + 100.0;  
        self.overlayWindow.backgroundColor = [UIColor clearColor];  
        self.overlayWindow.userInteractionEnabled = YES;  
        self.overlayWindow.hidden = NO;  
  
        UIViewController *rootVC = [[UIViewController alloc] init];  
        rootVC.view.backgroundColor = [UIColor clearColor];  
        rootVC.view.userInteractionEnabled = YES;  
        self.overlayWindow.rootViewController = rootVC;  
  
        [self setupFloatingButton:rootVC.view];  
        [self setupDashboardPanel:rootVC.view];  
        [self startMonitoring];  
    });  
}  
  
#pragma mark - Floating Button (Liquid Glass Style)  
  
- (void)setupFloatingButton:(UIView *)parentView {  
    CGFloat btnSize = 60.0;  
    self.floatingButton = [[UIView alloc] initWithFrame:CGRectMake(20, 100, btnSize, btnSize)];  
    self.floatingButton.layer.cornerRadius = btnSize / 2.0;  
    self.floatingButton.layer.masksToBounds = YES;  
    self.floatingButton.layer.borderWidth = 1.5;  
    self.floatingButton.layer.borderColor = [UIColor colorWithRed:0.2 green:0.9 blue:0.4 alpha:0.8].CGColor;  
  
    // Frosted Glass Blur Effect  
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];  
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];  
    blurView.frame = self.floatingButton.bounds;  
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;  
    [self.floatingButton addSubview:blurView];  
  
    // Centered Title Label  
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:self.floatingButton.bounds];  
    titleLabel.text = @"Kwar  
Nu";  
    titleLabel.numberOfLines = 2;  
    titleLabel.textAlignment = NSTextAlignmentCenter;  
    titleLabel.textColor = [UIColor colorWithRed:0.4 green:1.0 blue:0.6 alpha:1.0];  
    titleLabel.font = [UIFont boldSystemFontOfSize:12];  
    [self.floatingButton addSubview:titleLabel];  
  
    // Gestures  
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];  
    [self.floatingButton addGestureRecognizer:pan];  
  
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleDashboard)];  
    [self.floatingButton addGestureRecognizer:tap];  
  
    [parentView addSubview:self.floatingButton];  
}  
  
- (void)handlePan:(UIPanGestureRecognizer *)pan {  
    UIView *btn = pan.view;  
    CGPoint translation = [pan translationInView:btn.superview];  
    btn.center = CGPointMake(btn.center.x + translation.x, btn.center.y + translation.y);  
    [pan setTranslation:CGPointZero inView:btn.superview];  
  
    if (pan.state == UIPUIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateEnded) {  
        CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;  
        CGFloat targetX = (btn.center.x > screenWidth / 2.0) ? (screenWidth - btn.frame.size.width / 2.0 - 10) : (btn.frame.size.width / 2.0 + 10);  
        [UIView animateWithDuration:0.25 animations:^{  
            btn.center = CGPointMake(targetX, btn.center.y);  
        }];  
    }  
}  
  
#pragma mark - Dashboard Panel  
  
- (void)setupDashboardPanel:(UIView *)parentView {  
    CGFloat panelWidth = 280.0;  
    CGFloat panelHeight = 360.0;  
    CGFloat screenW = [UIScreen mainScreen].bounds.size.width;  
    CGFloat screenH = [UIScreen mainScreen].bounds.size.height;  
  
    self.dashboardPanel = [[UIView alloc] initWithFrame:CGRectMake((screenW - panelWidth) / 2.0, (screenH - panelHeight) / 2.0, panelWidth, panelHeight)];  
    self.dashboardPanel.layer.cornerRadius = 20.0;  
    self.dashboardPanel.layer.masksToBounds = YES;  
    self.dashboardPanel.layer.borderWidth = 1.0;  
    self.dashboardPanel.layer.borderColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.5 alpha:0.5].CGColor;  
    self.dashboardPanel.hidden = YES;  
  
    // Glass Background  
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];  
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];  
    blurView.frame = self.dashboardPanel.bounds;  
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;  
    [self.dashboardPanel addSubview:blurView];  
  
    // Header  
    UILabel *header = [[UILabel alloc] initWithFrame:CGRectMake(15, 12, panelWidth - 30, 24)];  
    header.text = @"⚡ Kwar Nu Booster";  
    header.textColor = [UIColor colorWithRed:0.2 green:1.0 blue:0.5 alpha:1.0];  
    header.font = [UIFont boldSystemFontOfSize:16];  
    [self.dashboardPanel addSubview:header];  
  
    // Metrics Labels  
    self.fpsLabel = [self createMetricLabelAtY:45 title:@"📊 FPS: --"];  
    self.ramLabel = [self createMetricLabelAtY:70 title:@"🧠 RAM: -- MB"];  
    self.batteryLabel = [self createMetricLabelAtY:95 title:@"🔋 Battery: --%"];  
    self.thermalLabel = [self createMetricLabelAtY:120 title:@"🌡️ Thermal: Nominal"];  
  
    // FPS Selector Section  
    UILabel *fpsTitle = [[UILabel alloc] initWithFrame:CGRectMake(15, 150, panelWidth - 30, 18)];  
    fpsTitle.text = @"Target FPS Lock:";  
    fpsTitle.textColor = [UIColor lightTextColor];  
    fpsTitle.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];  
    [self.dashboardPanel addSubview:fpsTitle];  
  
    UIButton *btn30 = [self createActionButton:@"30 FPS" frame:CGRectMake(15, 172, 75, 30) action:@selector(setFPS30)];  
    UIButton *btn60 = [self createActionButton:@"60 FPS" frame:CGRectMake(100, 172, 75, 30) action:@selector(setFPS60)];  
    UIButton *btn120 = [self createActionButton:@"120 FPS" frame:CGRectMake(185, 172, 80, 30) action:@selector(setFPS120)];  
    [self.dashboardPanel addSubview:btn30];  
    [self.dashboardPanel addSubview:btn60];  
    [self.dashboardPanel addSubview:btn120];  
  
    // Feature Toggles  
    UIButton *batteryBtn = [self createActionButton:@"🔋 Battery Saver [OFF]" frame:CGRectMake(15, 215, panelWidth - 30, 32) action:@selector(toggleBatterySaver:)];  
    [self.dashboardPanel addSubview:batteryBtn];  
  
    UIButton *perfBtn = [self createActionButton:@"🚀 Performance Boost" frame:CGRectMake(15, 255, panelWidth - 30, 32) action:@selector(triggerPerformanceBoost)];  
    [self.dashboardPanel addSubview:perfBtn];  
  
    UIButton *purgeBtn = [self createActionButton:@"🧹 Purge Cache & RAM" frame:CGRectMake(15, 295, panelWidth - 30, 32) action:@selector(purgeMemory)];  
    purgeBtn.backgroundColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:0.4];  
    [self.dashboardPanel addSubview:purgeBtn];  
  
    [parentView addSubview:self.dashboardPanel];  
}  
  
- (UILabel *)createMetricLabelAtY:(CGFloat)y title:(NSString *)title {  
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(15, y, 250, 20)];  
    lbl.text = title;  
    lbl.textColor = [UIColor whiteColor];  
    lbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];  
    [self.dashboardPanel addSubview:lbl];  
    return lbl;  
}  
  
- (UIButton *)createActionButton:(NSString *)title frame:(CGRect)frame action:(SEL)action {  
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];  
    btn.frame = frame;  
    [btn setTitle:title forState:UIControlStateNormal];  
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];  
    btn.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];  
    btn.backgroundColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.25 alpha:0.6];  
    btn.layer.cornerRadius = 8.0;  
    btn.layer.borderWidth = 0.5;  
    btn.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.2].CGColor;  
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];  
    return btn;  
}  
  
- (void)toggleDashboard {  
    self.dashboardPanel.hidden = !self.dashboardPanel.hidden;  
}  
  
#pragma mark - Live Monitoring  
  
- (void)startMonitoring {  
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(onTick:)];  
    [self applyTargetFPS];  
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];  
}  
  
- (void)onTick:(CADisplayLink *)link {  
    if (_lastTimestamp == 0) {  
        _lastTimestamp = link.timestamp;  
        return;  
    }  
  
    _frameCount++;  
    CFTimeInterval delta = link.timestamp - _lastTimestamp;  
    if (delta >= 1.0) {  
        _currentFPS = _frameCount / delta;  
        _frameCount = 0;  
        _lastTimestamp = link.timestamp;  
        [self updateDashboardLabels];  
    }  
}  
  
- (void)updateDashboardLabels {  
    if (self.dashboardPanel.hidden) return;  
  
    // FPS  
    self.fpsLabel.text = [NSString stringWithFormat:@"📊 FPS: %.1f", _currentFPS];  
  
    // Resident Memory (RAM)  
    struct mach_task_basic_info info;  
    mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;  
    if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&info, &count) == KERN_SUCCESS) {  
        double ramMB = (double)info.resident_size / (1024.0 * 1024.0);  
        self.ramLabel.text = [NSString stringWithFormat:@"🧠 RAM: %.1f MB", ramMB];  
    }  
  
    // Battery  
    float battLevel = [UIDevice currentDevice].batteryLevel;  
    if (battLevel >= 0.0) {  
        self.batteryLabel.text = [NSString stringWithFormat:@"🔋 Battery: %.0f%%", battLevel * 100.0];  
    } else {  
        self.batteryLabel.text = @"🔋 Battery: N/A";  
    }  
  
    // Thermal State  
    NSProcessInfoThermalState thermal = [NSProcessInfo processInfo].thermalState;  
    switch (thermal) {  
        case NSProcessInfoThermalStateNominal:  
            self.thermalLabel.text = @"🌡️ Thermal: 🟢 Nominal";  
            break;  
        case NSProcessInfoThermalStateFair:  
            self.thermalLabel.text = @"🌡️ Thermal: 🟡 Fair";  
            break;  
        case NSProcessInfoThermalStateSerious:  
            self.thermalLabel.text = @"🌡️ Thermal: 🟠 Serious";  
            break;  
        case NSProcessInfoThermalStateCritical:  
            self.thermalLabel.text = @"🌡️ Thermal: 🔴 Critical";  
            break;  
    }  
}  
  
#pragma mark - Actions & Tuning  
  
- (void)setFPS30 {  
    self.targetFPS = 30;  
    [self applyTargetFPS];  
}  
  
- (void)setFPS60 {  
    self.targetFPS = 60;  
    [self applyTargetFPS];  
}  
  
- (void)setFPS120 {  
    self.targetFPS = 120;  
    [self applyTargetFPS];  
}  
  
- (void)applyTargetFPS {  
    if (@available(iOS 15.0, *)) {  
        CAFrameRateRange range = CAFrameRateRangeMake(self.targetFPS / 2.0, self.targetFPS, self.targetFPS);  
        self.displayLink.preferredFrameRateRange = range;  
    } else {  
        self.displayLink.preferredFramesPerSecond = self.targetFPS;  
    }  
}  
  
- (void)toggleBatterySaver:(UIButton *)sender {  
    self.isBatterySaverActive = !self.isBatterySaverActive;  
    if (self.isBatterySaverActive) {  
        [sender setTitle:@"🔋 Battery Saver [ON]" forState:UIControlStateNormal];  
        sender.backgroundColor = [UIColor colorWithRed:0.1 green:0.6 blue:0.2 alpha:0.7];  
        self.targetFPS = 30;  
        [self applyTargetFPS];  
    } else {  
        [sender setTitle:@"🔋 Battery Saver [OFF]" forState:UIControlStateNormal];  
        sender.backgroundColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.25 alpha:0.6];  
        self.targetFPS = 60;  
        [self applyTargetFPS];  
    }  
}  
  
- (void)triggerPerformanceBoost {  
    [self purgeMemory];  
    self.targetFPS = 120;  
    [self applyTargetFPS];  
}  
  
- (void)purgeMemory {  
    [[NSURLCache sharedURLCache] removeAllCachedResponses];  
}  
  
@end  
  
#pragma clang diagnostic pop  
  
// Automatic Constructor Entry  
__attribute__((constructor))  
static void initializeKwarNuBooster(void) {  
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{  
        [[KwarNuBoosterOverlay sharedInstance] showOverlay];  
    });  
}
