
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <mach/mach.h>

@interface KwarNuBooster : NSObject
+ (void)showBoosterMenu;
+ (void)updateTick:(CADisplayLink *)link;
+ (void)handlePan:(UIPanGestureRecognizer *)pan;
+ (void)toggleMenu;
+ (void)applyBoost;
+ (double)getMemoryUsage;
@end

@implementation KwarNuBooster

static UIButton *floatingBtn;
static UIView *menuView;
static UILabel *fpsLabel;
static UILabel *infoLabel;
static CADisplayLink *displayLink;
static CFTimeInterval lastTime = 0;
static NSInteger frames = 0;
static BOOL isMenuOpen = NO;

+ (double)getMemoryUsage {
    struct mach_task_basic_info info = {0};
    mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;

    kern_return_t result = task_info(
        mach_task_self(),
        MACH_TASK_BASIC_INFO,
        (task_info_t)&info,
        &count
    );

    if (result == KERN_SUCCESS) {
        return (double)info.resident_size / (1024.0 * 1024.0);
    }

    return 0.0;
}

+ (UIWindow *)activeWindow {
    UIApplication *app = [UIApplication sharedApplication];

    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in app.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) {
                continue;
            }

            UIWindowScene *windowScene = (UIWindowScene *)scene;

            if (windowScene.activationState !=
                UISceneActivationStateForegroundActive) {
                continue;
            }

            for (UIWindow *window in windowScene.windows) {
                if (window.isKeyWindow) {
                    return window;
                }
            }

            if (windowScene.windows.count > 0) {
                return windowScene.windows.firstObject;
            }
        }
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return app.keyWindow;
#pragma clang diagnostic pop
}

+ (void)showBoosterMenu {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (floatingBtn != nil) {
            return;
        }

        UIWindow *window = [self activeWindow];

        if (window == nil) {
            return;
        }

        floatingBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        floatingBtn.frame = CGRectMake(20, 150, 60, 60);
        floatingBtn.backgroundColor =
            [UIColor colorWithRed:0.0
                            green:0.65
                             blue:0.35
                            alpha:0.9];
        floatingBtn.layer.cornerRadius = 30.0;
        floatingBtn.layer.borderWidth = 1.5;
        floatingBtn.layer.borderColor =
            [UIColor whiteColor].CGColor;

        [floatingBtn setTitle:@"FPS" forState:UIControlStateNormal];
        floatingBtn.titleLabel.font =
            [UIFont boldSystemFontOfSize:12.0];

        [floatingBtn addTarget:self
                        action:@selector(toggleMenu)
              forControlEvents:UIControlEventTouchUpInside];

        UIPanGestureRecognizer *pan =
            [[UIPanGestureRecognizer alloc]
                initWithTarget:self
                        action:@selector(handlePan:)];

        [floatingBtn addGestureRecognizer:pan];
        [window addSubview:floatingBtn];

        menuView = [[UIView alloc]
            initWithFrame:CGRectMake(20, 220, 260, 200)];

        menuView.backgroundColor =
            [UIColor colorWithRed:0.05
                            green:0.10
                             blue:0.15
                            alpha:0.95];

        menuView.layer.cornerRadius = 16.0;
        menuView.layer.borderWidth = 1.2;
        menuView.layer.borderColor =
            [UIColor colorWithRed:0.0
                            green:0.8
                             blue:0.4
                            alpha:1.0].CGColor;

        menuView.hidden = YES;

        UILabel *title = [[UILabel alloc]
            initWithFrame:CGRectMake(10, 10, 240, 25)];

        title.text = @"Kwar Nu Gaming Booster";
        title.textColor =
            [UIColor colorWithRed:0.0
                            green:1.0
                             blue:0.5
                            alpha:1.0];
        title.font = [UIFont boldSystemFontOfSize:14.0];
        title.textAlignment = NSTextAlignmentCenter;
        [menuView addSubview:title];

        infoLabel = [[UILabel alloc]
            initWithFrame:CGRectMake(15, 45, 230, 40)];

        infoLabel.text =
            @"RAM Usage: Calculating...\nStatus: Ready";
        infoLabel.numberOfLines = 2;
        infoLabel.textColor = [UIColor whiteColor];
        infoLabel.font = [UIFont systemFontOfSize:12.0];
        [menuView addSubview:infoLabel];

        UIButton *boostBtn =
            [UIButton buttonWithType:UIButtonTypeSystem];

        boostBtn.frame = CGRectMake(15, 95, 230, 35);
        boostBtn.backgroundColor =
            [UIColor colorWithRed:0.0
                            green:0.8
                             blue:0.4
                            alpha:1.0];

        [boostBtn setTitle:@"Refresh Status"
                  forState:UIControlStateNormal];
        [boostBtn setTitleColor:[UIColor blackColor]
                       forState:UIControlStateNormal];
        boostBtn.layer.cornerRadius = 8.0;

        [boostBtn addTarget:self
                     action:@selector(applyBoost)
           forControlEvents:UIControlEventTouchUpInside];

        [menuView addSubview:boostBtn];

        UIButton *closeBtn =
            [UIButton buttonWithType:UIButtonTypeSystem];

        closeBtn.frame = CGRectMake(15, 140, 230, 35);
        closeBtn.backgroundColor =
            [UIColor colorWithWhite:0.3 alpha:0.8];

        [closeBtn setTitle:@"Close Menu"
                  forState:UIControlStateNormal];
        [closeBtn setTitleColor:[UIColor whiteColor]
                       forState:UIControlStateNormal];
        closeBtn.layer.cornerRadius = 8.0;

        [closeBtn addTarget:self
                     action:@selector(toggleMenu)
           forControlEvents:UIControlEventTouchUpInside];

        [menuView addSubview:closeBtn];
        [window addSubview:menuView];

        displayLink =
            [CADisplayLink displayLinkWithTarget:self
                                         selector:@selector(updateTick:)];

        [displayLink addToRunLoop:[NSRunLoop mainRunLoop]
                          forMode:NSRunLoopCommonModes];
    });
}

+ (void)handlePan:(UIPanGestureRecognizer *)pan {
    UIView *view = pan.view;
    UIView *parent = view.superview;

    if (view == nil || parent == nil) {
        return;
    }

    CGPoint translation = [pan translationInView:parent];

    CGPoint newCenter = CGPointMake(
        view.center.x + translation.x,
        view.center.y + translation.y
    );

    CGFloat halfWidth = view.bounds.size.width / 2.0;
    CGFloat halfHeight = view.bounds.size.height / 2.0;

    newCenter.x = MAX(halfWidth,
                      MIN(parent.bounds.size.width - halfWidth,
                          newCenter.x));

    newCenter.y = MAX(halfHeight,
                      MIN(parent.bounds.size.height - halfHeight,
                          newCenter.y));

    view.center = newCenter;
    [pan setTranslation:CGPointZero inView:parent];

    if (isMenuOpen && menuView != nil) {
        menuView.center =
            CGPointMake(newCenter.x, newCenter.y + 140);
    }
}

+ (void)toggleMenu {
    if (menuView == nil) {
        return;
    }

    isMenuOpen = !isMenuOpen;
    menuView.hidden = !isMenuOpen;

    if (isMenuOpen) {
        double ram = [self getMemoryUsage];

        infoLabel.text = [NSString stringWithFormat:
            @"RAM Usage: %.1f MB\nStatus: Ready", ram];
    }
}

+ (void)applyBoost {
    double ram = [self getMemoryUsage];

    infoLabel.text = [NSString stringWithFormat:
        @"RAM Usage: %.1f MB\nStatus: Refreshed", ram];
}

+ (void)updateTick:(CADisplayLink *)link {
    if (lastTime == 0) {
        lastTime = link.timestamp;
        return;
    }

    frames++;

    CFTimeInterval elapsed = link.timestamp - lastTime;

    if (elapsed >= 1.0) {
        double currentFPS = (double)frames / elapsed;
        frames = 0;
        lastTime = link.timestamp;

        if (fpsLabel != nil) {
            fpsLabel.text = [NSString stringWithFormat:
                @"%.0f FPS", currentFPS];
        }

        [floatingBtn setTitle:
            [NSString stringWithFormat:@"%.0f FPS", currentFPS]
                      forState:UIControlStateNormal];
    }
}

@end

__attribute__((constructor))
static void init_booster(void) {
    @autoreleasepool {
        [[NSNotificationCenter defaultCenter]
            addObserverForName:UIApplicationDidFinishLaunchingNotification
                        object:nil
                         queue:[NSOperationQueue mainQueue]
                    usingBlock:^(__unused NSNotification *note) {
            [KwarNuBooster showBoosterMenu];
        }];
    }
}
