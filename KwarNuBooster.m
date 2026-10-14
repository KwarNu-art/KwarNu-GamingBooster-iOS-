//  
//  KwarNuBooster.m  
//  KwarNu-GamingBooster-iOS  
//  
//  Created for In-App Performance Debugging and Game Optimization.  
//  
  
#import <UIKit/UIKit.h>  
#import <QuartzCore/QuartzCore.h>  
#import <mach/mach.h>  
#import <objc/runtime.h>  
  
#pragma mark - Forward Declarations & Interfaces  
  
@interface KwarNuBooster : NSObject  
  
@property (nonatomic, strong) UIWindow *overlayWindow;  
@property (nonatomic, strong) UIView *floatingButton;  
@property (nonatomic, strong) UIView *panelView;  
@property (nonatomic, strong) CADisplayLink *displayLink;  
  
@property (nonatomic, assign) CFTimeInterval lastTimestamp;  
@property (nonatomic, assign) NSInteger frameCount;  
@property (nonatomic, assign) double currentFPS;  
  
@property (nonatomic, assign) BOOL isPanelOpen;  
@property (nonatomic, assign) BOOL isBatterySaverActive;  
@property (nonatomic, assign) BOOL isSuperBoosterActive;  
@property (nonatomic, assign) NSInteger lockedFPS; // 0 = default, 30, 60, 120  
  
@property (nonatomic, strong) UILabel *fpsLabel;  
@property (nonatomic, strong) UILabel *memoryLabel;  
@property (nonatomic, strong) UILabel *batteryLabel;  
@property (nonatomic, strong) UILabel *thermalLabel;  
  
+ (instancetype)sharedInstance;  
- (void)startOverlay;  
- (void)toggleDashboard;  
  
@end  
  
#pragma mark - Mach Memory Helper  
  
static double GetMachMemoryUsageMB(void) {  
    struct mach_task_basic_info info;  
    mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;  
    kern_return_t kr = task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&info, &count);  
    if (kr != KERN_SUCCESS) {  
        return 0.0;  
    }  
    return (double)info.resident_size / (1024.0 * 1024.0);  
}  
  
#pragma mark - Implementation  
  
@implementation KwarNuBooster  
  
+ (instancetype)sharedInstance {  
    static KwarNuBooster *instance = nil;  
    static dispatch_once_t onceToken;  
    dispatch_once(&onceToken, ^{  
        instance = [[self alloc] init];  
    });  
    return instance;  
}  
  
- (instancetype)init {  
    self = [super init];  
    if (self) {  
        _currentFPS = 60.0;  
        _lockedFPS = 0;  
        _isBatterySaverActive = NO;  
        _isSuperBoosterActive = NO;  
        _isPanelOpen = NO;  
    }  
    return self;  
}  
  
- (void)startOverlay {  
    dispatch_async(dispatch_get_main_queue(), ^{  
        if (self.overlayWindow) return;  
  
        // 1. Setup Pass-through Overlay Window  
        CGRect screenBounds = [UIScreen mainScreen].bounds;  
        self.overlayWindow = [[UIWindow alloc] initWithFrame:screenBounds];  
        self.overlayWindow.windowLevel = UIWindowLevelStatusBar + 100.0;  
        self.overlayWindow.backgroundColor = [UIColor clearColor];  
        self.overlayWindow.hidden = NO;  
  
        UIViewController *rootVC = [[UIViewController alloc] init];  
        rootVC.view.backgroundColor = [UIColor clearColor];  
        rootVC.view.userInteractionEnabled = YES;  
        self.overlayWindow.rootViewController = rootVC;  
  
        // 2. Create Floating Liquid Glass Button  
        [self setupFloatingButtonInView:rootVC.view];  
  
        // 3. Create Dashboard Panel (initially hidden)  
        [self setupDashboardPanelInView:rootVC.view];  
  
        // 4. Start Performance Monitor DisplayLink  
        [self setupDisplayLink];  
  
        // Enable Battery Monitoring  
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;  
    });  
}  
  
#pragma mark - Floating Liquid Glass Button  
  
- (void)setupFloatingButtonInView:(UIView *)parentView {  
    CGFloat btnSize = 64.0;  
    CGRect initialFrame = CGRectMake(24, 120, btnSize, btnSize);  
  
    self.floatingButton = [[UIView alloc] initWithFrame:initialFrame];  
    self.floatingButton.backgroundColor = [UIColor clearColor];  
    self.floatingButton.layer.cornerRadius = btnSize / 2.0;  
    self.floatingButton.layer.masksToBounds = NO;  
  
    // Liquid Glass Frosted Blur  
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];  
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];  
    blurView.frame = self.floatingButton.bounds;  
    blurView.layer.cornerRadius = btnSize / 2.0;  
    blurView.layer.masksToBounds = YES;  
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;  
    blurView.userInteractionEnabled = NO;  
    [self.floatingButton addSubview:blurView];  
  
    // Subtle Liquid Glass Tint & Border Glow  
    UIView *tintView = [[UIView alloc] initWithFrame:self.floatingButton.bounds];  
    tintView.backgroundColor = [UIColor colorWithRed:0.20 green:0.85 blue:0.45 alpha:0.18]; // Mint Green Glass  
    tintView.layer.cornerRadius = btnSize / 2.0;  
    tintView.layer.borderColor = [UIColor colorWithRed:0.35 green:0.95 blue:0.55 alpha:0.65].CGColor;  
    tintView.layer.borderWidth = 1.5;  
    tintView.layer.masksToBounds = YES;  
    tintView.userInteractionEnabled = NO;  
    [self.floatingButton addSubview:tintView];  
  
    // Shadow for Floating Depth  
    self.floatingButton.layer.shadowColor = [UIColor colorWithRed:0.15 green:0.80 blue:0.40 alpha:0.40].CGColor;  
    self.floatingButton.layer.shadowRadius = 10.0;  
    self.floatingButton.layer.shadowOpacity = 0.85;  
    self.floatingButton.layer.shadowOffset = CGSizeMake(0, 4);  
  
    // Centered "Kwar Nu" Label  
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:self.floatingButton.bounds];  
    titleLabel.text = @"Kwar  
Nu";  
    titleLabel.numberOfLines = 2;  
    titleLabel.textAlignment = NSTextAlignmentCenter;  
    titleLabel.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightHeavy];  
    titleLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.95];  
    titleLabel.userInteractionEnabled = NO;  
    [self.floatingButton addSubview:titleLabel];  
  
    // Gestures: Drag & Tap  
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];  
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleDashboard)];  
    [self.floatingButton addGestureRecognizer:pan];  
    [self.floatingButton addGestureRecognizer:tap];  
  
    [parentView addSubview:self.floatingButton];  
}  
  
- (void)handlePan:(UIPanGestureRecognizer *)pan {  
    UIView *view = self.floatingButton;  
    CGPoint translation = [pan translationInView:view.superview];  
    CGPoint newCenter = CGPointMake(view.center.x + translation.x, view.center.y + translation.y);  
  
    // Bounds clamping  
    CGRect bounds = view.superview.bounds;  
    CGFloat halfW = view.frame.size.width / 2.0;  
    CGFloat halfH = view.frame.size.height / 2.0;  
    newCenter.x = MAX(halfW + 10, MIN(bounds.size.width - halfW - 10, newCenter.x));  
    newCenter.y = MAX(halfH + 40, MIN(bounds.size.height - halfH - 40, newCenter.y));  
  
    view.center = newCenter;  
    [pan setTranslation:CGPointZero inView:view.superview];  
  
    // Edge Snap on release  
    if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {  
        CGFloat snapX = (newCenter.x < bounds.size.width / 2.0) ? (halfW + 12) : (bounds.size.width - halfW - 12);  
        [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.75 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{  
            view.center = CGPointMake(snapX, newCenter.y);  
        } completion:nil];  
    }  
}  
  
#pragma mark - Dashboard Panel (Frosted Liquid Glass UI)  
  
- (void)setupDashboardPanelInView:(UIView *)parentView {  
    CGFloat panelW = MIN(parentView.bounds.size.width - 32, 340);  
    CGFloat panelH = 460;  
    CGRect panelFrame = CGRectMake((parentView.bounds.size.width - panelW) / 2.0,  
                                   (parentView.bounds.size.height - panelH) / 2.0,  
                                   panelW, panelH);  
  
    self.panelView = [[UIView alloc] initWithFrame:panelFrame];  
    self.panelView.layer.cornerRadius = 24.0;  
    self.panelView.layer.masksToBounds = NO;  
    self.panelView.alpha = 0.0;  
    self.panelView.transform = CGAffineTransformMakeScale(0.85, 0.85);  
  
    // Frosted Glass Blur  
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialDark];  
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];  
    blurView.frame = self.panelView.bounds;  
    blurView.layer.cornerRadius = 24.0;  
    blurView.layer.masksToBounds = YES;  
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;  
    [self.panelView addSubview:blurView];  
  
    // Glass Border  
    UIView *borderOverlay = [[UIView alloc] initWithFrame:self.panelView.bounds];  
    borderOverlay.backgroundColor = [UIColor colorWithRed:0.12 green:0.25 blue:0.18 alpha:0.40];  
    borderOverlay.layer.cornerRadius = 24.0;  
    borderOverlay.layer.borderWidth = 1.2;  
    borderOverlay.layer.borderColor = [UIColor colorWithRed:0.30 green:0.90 blue:0.55 alpha:0.45].CGColor;  
    borderOverlay.layer.masksToBounds = YES;  
    [self.panelView addSubview:borderOverlay];  
  
    // Scrollable Content Container  
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:self.panelView.bounds];  
    scrollView.contentSize = CGSizeMake(panelW, 510);  
    scrollView.showsVerticalScrollIndicator = NO;  
    [self.panelView addSubview:scrollView];  
  
    // Header Title  
    UILabel *header = [[UILabel alloc] initWithFrame:CGRectMake(20, 18, panelW - 70, 28)];  
    header.text = @"⚡ KWAR NU BOOSTER";  
    header.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBlack];  
    header.textColor = [UIColor colorWithRed:0.35 green:0.95 blue:0.55 alpha:1.0];  
    [scrollView addSubview:header];  
  
    // Close Button  
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];  
    closeBtn.frame = CGRectMake(panelW - 48, 14, 32, 32);  
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];  
    closeBtn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];  
    [closeBtn setTitleColor:[UIColor colorWithWhite:0.8 alpha:0.9] forState:UIControlStateNormal];  
    closeBtn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.12];  
    closeBtn.layer.cornerRadius = 16;  
    [closeBtn addTarget:self action:@selector(toggleDashboard) forControlEvents:UIControlEventTouchUpInside];  
    [scrollView addSubview:closeBtn];  
  
    CGFloat curY = 56;  
  
    // --- Section 1: Real-time Metrics ---  
    UIView *statsCard = [self createCardAtY:curY width:panelW - 32 height:105];  
    [scrollView addSubview:statsCard];  
  
    self.fpsLabel = [self createStatLabel:@"📊 FPS: 60.0 fps (16.6 ms)" y:8 inCard:statsCard];  
    self.memoryLabel = [self createStatLabel:@"🧠 RAM: 0.0 MB" y:32 inCard:statsCard];  
    self.batteryLabel = [self createStatLabel:@"🔋 Battery: 100% (Normal)" y:56 inCard:statsCard];  
    self.thermalLabel = [self createStatLabel:@"🌡️ Thermal State: Nominal" y:80 inCard:statsCard];  
  
    curY += 115;  
  
    // --- Section 2: FPS Frame Rate Locker ---  
    UILabel *fpsHeader = [self createSectionHeader:@"🎯 FPS FRAME LOCKER" y:curY];  
    [scrollView addSubview:fpsHeader];  
    curY += 24;  
  
    UISegmentedControl *fpsSegment = [[UISegmentedControl alloc] initWithItems:@[@"Default", @"30 Hz", @"60 Hz", @"120 Hz"]];  
    fpsSegment.frame = CGRectMake(16, curY, panelW - 32, 34);  
    fpsSegment.selectedSegmentIndex = 0;  
    [fpsSegment setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor], NSFontAttributeName: [UIFont systemFontOfSize:12 weight:UIFontWeightBold]} forState:UIControlStateNormal];  
    [fpsSegment addTarget:self action:@selector(fpsSegmentChanged:) forControlEvents:UIControlEventValueChanged];  
    [scrollView addSubview:fpsSegment];  
  
    curY += 46;  
  
    // --- Section 3: Battery Saver & Super Booster ---  
    UILabel *modesHeader = [self createSectionHeader:@"⚡ PERFORMANCE & POWER MODES" y:curY];  
    [scrollView addSubview:modesHeader];  
    curY += 24;  
  
    // Battery Saver Toggle  
    UIView *batteryRow = [self createSwitchRowWithTitle:@"🔋 Battery Saver Mode" y:curY width:panelW - 32 action:@selector(batterySaverToggled:)];  
    [scrollView addSubview:batteryRow];  
    curY += 46;  
  
    // Super Booster Toggle  
    UIView *boosterRow = [self createSwitchRowWithTitle:@"🚀 Super Booster Mode" y:curY width:panelW - 32 action:@selector(superBoosterToggled:)];  
    [scrollView addSubview:boosterRow];  
    curY += 46;  
  
    // Clean Memory Action Button  
    UIButton *purgeBtn = [UIButton buttonWithType:UIButtonTypeSystem];  
    purgeBtn.frame = CGRectMake(16, curY, panelW - 32, 38);  
    purgeBtn.backgroundColor = [UIColor colorWithRed:0.20 green:0.75 blue:0.45 alpha:0.35];  
    purgeBtn.layer.cornerRadius = 12;  
    purgeBtn.layer.borderColor = [UIColor colorWithRed:0.35 green:0.90 blue:0.55 alpha:0.6].CGColor;  
    purgeBtn.layer.borderWidth = 1.0;  
    [purgeBtn setTitle:@"🧹 Instant RAM Purge & Cache Clean" forState:UIControlStateNormal];  
    [purgeBtn setTitleColor:[UIColor colorWithWhite:1.0 alpha:0.95] forState:UIControlStateNormal];  
    purgeBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];  
    [purgeBtn addTarget:self action:@selector(instantRamPurge) forControlEvents:UIControlEventTouchUpInside];  
    [scrollView addSubview:purgeBtn];  
  
    [parentView addSubview:self.panelView];  
}  
  
- (UIView *)createCardAtY:(CGFloat)y width:(CGFloat)w height:(CGFloat)h {  
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(16, y, w, h)];  
    card.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.28];  
    card.layer.cornerRadius = 14;  
    card.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.10].CGColor;  
    card.layer.borderWidth = 1.0;  
    return card;  
}  
  
- (UILabel *)createSectionHeader:(NSString *)title y:(CGFloat)y {  
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(18, y, 280, 20)];  
    lbl.text = title;  
    lbl.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightHeavy];  
    lbl.textColor = [UIColor colorWithWhite:0.75 alpha:0.9];  
    return lbl;  
}  
  
- (UILabel *)createStatLabel:(NSString *)text y:(CGFloat)y inCard:(UIView *)card {  
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(12, y, card.bounds.size.width - 24, 20)];  
    lbl.text = text;  
    lbl.font = [UIFont fontWithName:@"Menlo" size:11.5] ?: [UIFont monospacedSystemFontOfSize:11.5 weight:UIFontWeightMedium];  
    lbl.textColor = [UIColor colorWithWhite:0.92 alpha:1.0];  
    [card addSubview:lbl];  
    return lbl;  
}  
  
- (UIView *)createSwitchRowWithTitle:(NSString *)title y:(CGFloat)y width:(CGFloat)w action:(SEL)action {  
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(16, y, w, 40)];  
    row.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.22];  
    row.layer.cornerRadius = 10;  
  
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(12, 10, w - 80, 20)];  
    lbl.text = title;  
    lbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemiBold];  
    lbl.textColor = [UIColor whiteColor];  
    [row addSubview:lbl];  
  
    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(w - 62, 5, 51, 31)];  
    sw.onTintColor = [UIColor colorWithRed:0.20 green:0.80 blue:0.45 alpha:1.0];  
    [sw addTarget:self action:action forControlEvents:UIControlEventValueChanged];  
    [row addSubview:sw];  
  
    return row;  
}  
  
#pragma mark - Actions & Toggles  
  
- (void)toggleDashboard {  
    self.isPanelOpen = !self.isPanelOpen;  
    [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.4 options:UIViewAnimationOptionCurveEaseInOut animations:^{  
        if (self.isPanelOpen) {  
            self.panelView.alpha = 1.0;  
            self.panelView.transform = CGAffineTransformIdentity;  
        } else {  
            self.panelView.alpha = 0.0;  
            self.panelView.transform = CGAffineTransformMakeScale(0.85, 0.85);  
        }  
    } completion:nil];  
}  
  
- (void)fpsSegmentChanged:(UISegmentedControl *)sender {  
    NSInteger index = sender.selectedSegmentIndex;  
    switch (index) {  
        case 0:  
            self.lockedFPS = 0; // Default  
            break;  
        case 1:  
            self.lockedFPS = 30; // 30 Hz  
            break;  
        case 2:  
            self.lockedFPS = 60; // 60 Hz  
            break;  
        case 3:  
            self.lockedFPS = 120; // 120 Hz ProMotion  
            break;  
    }  
    [self applyFPSLock];  
}  
  
- (void)applyFPSLock {  
    if (@available(iOS 15.0, *)) {  
        if (self.lockedFPS > 0) {  
            CAFrameRateRange range = CAFrameRateRangeMake(self.lockedFPS / 2.0, self.lockedFPS, self.lockedFPS);  
            self.displayLink.preferredFrameRateRange = range;  
        } else {  
            self.displayLink.preferredFrameRateRange = CAFrameRateRangeDefault;  
        }  
    } else {  
        self.displayLink.preferredFramesPerSecond = self.lockedFPS;  
    }  
}  
  
- (void)batterySaverToggled:(UISwitch *)sender {  
    self.isBatterySaverActive = sender.isOn;  
    if (self.isBatterySaverActive) {  
        // Drop FPS to 30 to conserve GPU/CPU power  
        self.lockedFPS = 30;  
        [self applyFPSLock];  
    } else {  
        self.lockedFPS = 60;  
        [self applyFPSLock];  
    }  
}  
  
- (void)superBoosterToggled:(UISwitch *)sender {  
    self.isSuperBoosterActive = sender.isOn;  
    if (self.isSuperBoosterActive) {  
        // Boost thread priority & clean RAM  
        [self instantRamPurge];  
        if (@available(iOS 15.0, *)) {  
            // Request Max Refresh Rate  
            CGFloat maxRate = [UIScreen mainScreen].maximumFramesPerSecond;  
            CAFrameRateRange maxRange = CAFrameRateRangeMake(60, maxRate, maxRate);  
            self.displayLink.preferredFrameRateRange = maxRange;  
        }  
    }  
}  
  
- (void)instantRamPurge {  
    // Evict all UI memory caches  
    [[NSURLCache sharedURLCache] removeAllCachedResponses];  
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidReceiveMemoryWarningNotification object:nil];  
  
    // Animate button feedback  
    [UIView animateWithDuration:0.2 animations:^{  
        self.floatingButton.transform = CGAffineTransformMakeScale(1.15, 1.15);  
    } completion:^(BOOL finished) {  
        [UIView animateWithDuration:0.2 animations:^{  
            self.floatingButton.transform = CGAffineTransformIdentity;  
        }];  
    }];  
}  
  
#pragma mark - CADisplayLink & Metrics Poller  
  
- (void)setupDisplayLink {  
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(handleDisplayFrame:)];  
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];  
}  
  
- (void)handleDisplayFrame:(CADisplayLink *)link {  
    if (self.lastTimestamp == 0) {  
        self.lastTimestamp = link.timestamp;  
        return;  
    }  
  
    self.frameCount++;  
    CFTimeInterval delta = link.timestamp - self.lastTimestamp;  
  
    if (delta >= 0.5) { // Refresh metrics every 500ms  
        self.currentFPS = (double)self.frameCount / delta;  
        self.frameCount = 0;  
        self.lastTimestamp = link.timestamp;  
  
        [self updateDashboardMetrics];  
    }  
}  
  
- (void)updateDashboardMetrics {  
    if (!self.isPanelOpen) return;  
  
    // 1. FPS & Frame Time  
    double frameTimeMs = (self.currentFPS > 0) ? (1000.0 / self.currentFPS) : 0.0;  
    self.fpsLabel.text = [NSString stringWithFormat:@"📊 FPS: %.1f fps (%.1f ms)", self.currentFPS, frameTimeMs];  
  
    // 2. RAM Usage  
    double ramMB = GetMachMemoryUsageMB();  
    self.memoryLabel.text = [NSString stringWithFormat:@"🧠 RAM: %.1f MB", ramMB];  
  
    // 3. Battery Status  
    float batteryLevel = [UIDevice currentDevice].batteryLevel * 100.0;  
    UIDeviceBatteryState state = [UIDevice currentDevice].batteryState;  
    NSString *stateStr = (state == UIDeviceBatteryStateCharging || state == UIDeviceBatteryStateFull) ? @"Charging ⚡" : @"Discharging";  
    if (batteryLevel < 0) {  
        self.batteryLabel.text = @"🔋 Battery: Simulator/Unavailable";  
    } else {  
        self.batteryLabel.text = [NSString stringWithFormat:@"🔋 Battery: %.0f%% (%@)", batteryLevel, stateStr];  
    }  
  
    // 4. Thermal State  
    if (@available(iOS 11.0, *)) {  
        NSProcessInfoThermalState thermal = [NSProcessInfo processInfo].thermalState;  
        NSString *thermalStr = @"Nominal 🟢";  
        if (thermal == NSProcessInfoThermalStateFair) thermalStr = @"Fair 🟡";  
        else if (thermal == NSProcessInfoThermalStateSerious) thermalStr = @"Serious 🟠";  
        else if (thermal == NSProcessInfoThermalStateCritical) thermalStr = @"Critical 🔥";  
        self.thermalLabel.text = [NSString stringWithFormat:@"🌡️ Thermal: %@", thermalStr];  
    }  
}  
  
@end  
  
#pragma mark - Constructor Initializer  
  
__attribute__((constructor)) static void KwarNuBoosterAutoInit(void) {  
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification  
                                                      object:nil  
                                                       queue:[NSOperationQueue mainQueue]  
                                                  usingBlock:^(NSNotification * _Nonnull note) {  
        [[KwarNuBooster sharedInstance] startOverlay];  
    }];  
}
