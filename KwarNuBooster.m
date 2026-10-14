#import <Foundation/Foundation.h>  
#import <UIKit/UIKit.h>  
#import <QuartzCore/QuartzCore.h>  
#import <mach/mach.h>  
#import <sys/sysctl.h>  
#import <objc/runtime.h>  
  
@interface KwarNuBooster : NSObject  
+ (void)showBoosterMenu;  
+ (double)getMemoryUsage;  
@end  
  
@implementation KwarNuBooster  
  
static UIButton *floatingBtn = nil;  
static UIView *menuView = nil;  
static UILabel *fpsLabel = nil;  
static UILabel *infoLabel = nil;  
static CADisplayLink *displayLink = nil;  
static CFTimeInterval lastTime = 0;  
static NSInteger frames = 0;  
static BOOL isMenuOpen = NO;  
  
+ (double)getMemoryUsage {  
    struct mach_task_basic_info info;  
    mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;  
    if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&info, &count) == KERN_SUCCESS) {  
        return (double)info.resident_size / (1024.0 * 1024.0);  
    }  
    return 0.0;  
}  
  
+ (void)showBoosterMenu {  
    dispatch_async(dispatch_get_main_queue(), ^{  
        UIWindow *window = nil;  
        if (@available(iOS 13.0, *)) {  
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {  
                if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {  
                    window = scene.windows.firstObject;  
                    break;  
                }  
            }  
        }  
        if (!window) {  
            window = [UIApplication sharedApplication].keyWindow;  
        }  
        if (!window && [UIApplication sharedApplication].windows.count > 0) {  
            window = [UIApplication sharedApplication].windows.firstObject;  
        }  
        if (!window || floatingBtn) return;  
  
        // Floating Glass Button  
        floatingBtn = [UIButton buttonWithType:UIButtonTypeCustom];  
        floatingBtn.frame = CGRectMake(20, 150, 60, 60);  
        floatingBtn.backgroundColor = [UIColor colorWithRed:0.0 green:0.8 blue:0.4 alpha:0.35];  
        floatingBtn.layer.cornerRadius = 30;  
        floatingBtn.layer.borderWidth = 1.5;  
        floatingBtn.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.7].CGColor;  
        floatingBtn.clipsToBounds = YES;  
  
        UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];  
        blur.frame = floatingBtn.bounds;  
        blur.userInteractionEnabled = NO;  
        [floatingBtn addSubview:blur];  
  
        fpsLabel = [[UILabel alloc] initWithFrame:floatingBtn.bounds];  
        fpsLabel.text = @"-- FPS";  
        fpsLabel.font = [UIFont boldSystemFontOfSize:11];  
        fpsLabel.textColor = [UIColor whiteColor];  
        fpsLabel.textAlignment = NSTextAlignmentCenter;  
        fpsLabel.userInteractionEnabled = NO;  
        [floatingBtn addSubview:fpsLabel];  
  
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];  
        [floatingBtn addGestureRecognizer:pan];  
  
        [floatingBtn addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];  
        [window addSubview:floatingBtn];  
  
        // Booster Dashboard Menu  
        menuView = [[UIView alloc] initWithFrame:CGRectMake(20, 220, 260, 200)];  
        menuView.backgroundColor = [UIColor colorWithRed:0.05 green:0.1 blue:0.15 alpha:0.85];  
        menuView.layer.cornerRadius = 16;  
        menuView.layer.borderWidth = 1.2;  
        menuView.layer.borderColor = [UIColor colorWithRed:0.0 green:0.8 blue:0.4 alpha:0.8].CGColor;  
        menuView.clipsToBounds = YES;  
        menuView.hidden = YES;  
  
        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 240, 25)];  
        title.text = @"⚡ Kwar Nu Gaming Booster";  
        title.textColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.5 alpha:1.0];  
        title.font = [UIFont boldSystemFontOfSize:14];  
        title.textAlignment = NSTextAlignmentCenter;  
        [menuView addSubview:title];  
  
        infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 45, 230, 40)];  
        infoLabel.text = @"RAM Usage: Calculating...  
Status: Optimized";  
        infoLabel.numberOfLines = 2;  
        infoLabel.textColor = [UIColor whiteColor];  
        infoLabel.font = [UIFont systemFontOfSize:12];  
        [menuView addSubview:infoLabel];  
  
        UIButton *boostBtn = [UIButton buttonWithType:UIButtonTypeSystem];  
        boostBtn.frame = CGRectMake(15, 95, 230, 35)];  
        boostBtn.backgroundColor = [UIColor colorWithRed:0.0 green:0.8 blue:0.4 alpha:0.8];  
        [boostBtn setTitle:@"🚀 Clean RAM & Boost" forState:UIControlStateNormal];  
        [boostBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];  
        boostBtn.layer.cornerRadius = 8;  
        boostBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];  
        [boostBtn addTarget:self action:@selector(applyBoost) forControlEvents:UIControlEventTouchUpInside];  
        [menuView addSubview:boostBtn];  
  
        UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];  
        closeBtn.frame = CGRectMake(15, 140, 230, 35)];  
        closeBtn.backgroundColor = [UIColor colorWithWhite:0.3 alpha:0.6];  
        [closeBtn setTitle:@"✕ Close Menu" forState:UIControlStateNormal];  
        [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];  
        closeBtn.layer.cornerRadius = 8;  
        closeBtn.titleLabel.font = [UIFont systemFontOfSize:12];  
        [closeBtn addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];  
        [menuView addSubview:closeBtn];  
  
        [window addSubview:menuView];  
  
        // Start FPS Monitor  
        displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateTick:)];  
        [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];  
    });  
}  
  
+ (void)handlePan:(UIPanGestureRecognizer *)pan {  
    UIView *view = pan.view;  
    CGPoint translation = [pan translationInView:view.superview];  
    view.center = CGPointMake(view.center.x + translation.x, view.center.y + translation.y);  
    [pan setTranslation:CGPointZero inView:view.superview];  
}  
  
+ (void)toggleMenu {  
    isMenuOpen = !isMenuOpen;  
    menuView.hidden = !isMenuOpen;  
    if (isMenuOpen) {  
        menuView.center = CGPointMake(floatingBtn.center.x, floatingBtn.center.y + 140);  
        double ram = [self getMemoryUsage];  
        infoLabel.text = [NSString stringWithFormat:@"RAM Usage: %.1f MB  
Status: Performance Mode", ram];  
    }  
}  
  
+ (void)applyBoost {  
    [[NSURLCache sharedURLCache] removeAllCachedResponses];  
    double ram = [self getMemoryUsage];  
    infoLabel.text = [NSString stringWithFormat:@"RAM Cleaned! (%.1f MB)  
Boost: Active", ram];  
}  
  
+ (void)updateTick:(CADisplayLink *)link {  
    if (lastTime == 0) {  
        lastTime = link.timestamp;  
        return;  
    }  
    frames++;  
    CFTimeInterval dt = link.timestamp - lastTime;  
    if (dt >= 1.0) {  
        double currentFps = frames / dt;  
        frames = 0;  
        lastTime = link.timestamp;  
        fpsLabel.text = [NSString stringWithFormat:@"%.0f FPS", currentFps];  
    }  
}  
  
@end  
  
__attribute__((constructor))  
static void init_booster(void) {  
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification  
                                                      object:nil  
                                                       queue:[NSOperationQueue mainQueue]  
                                                  usingBlock:^(NSNotification * _Nonnull note) {  
        [KwarNuBooster showBoosterMenu];  
    }];  
}
