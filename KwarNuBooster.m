#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <mach/mach.h>

@interface KwarNuBooster : NSObject

+ (void)start;
+ (void)showBoosterMenu;
+ (void)handlePan:(UIPanGestureRecognizer *)pan;
+ (void)toggleMenu;
+ (void)refreshStatus;
+ (void)updateTick:(CADisplayLink *)link;
+ (double)getMemoryUsage;

@end

@implementation KwarNuBooster

static UIButton *floatingButton;
static UIView *menuView;
static UILabel *fpsLabel;
static UILabel *infoLabel;
static CADisplayLink *displayLink;
static CFTimeInterval lastTime = 0.0;
static NSInteger frameCount = 0;
static BOOL menuIsOpen = NO;

+ (double)getMemoryUsage {
    struct mach_task_basic_info info = {0};
    mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;

    kern_return_t result = task_info(
        mach_task_self(),
        MACH_TASK_BASIC_INFO,
        (task_info_t)&info,
        &count
    );

    if (result != KERN_SUCCESS) {
        return 0.0;
    }

    return (double)info.resident_size / (1024.0 * 1024.0);
}

+ (UIWindow *)activeWindow {
    UIApplication *application =
        [UIApplication sharedApplication];

    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in application.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) {
                continue;
            }

            if (scene.activationState !=
                UISceneActivationStateForegroundActive) {
                continue;
            }

            UIWindowScene *windowScene = (UIWindowScene *)scene;

            for (UIWindow *window in windowScene.windows) {
                if (window.isKeyWindow) {
                    return window;
                }
            }
        }
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return application.keyWindow;
#pragma clang diagnostic pop
}

+ (void)start {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showBoosterMenu];
    });
}

+ (void)showBoosterMenu {
    if (floatingButton != nil) {
        return;
    }

    UIWindow *window = [self activeWindow];

    if (window == nil) {
        NSLog(@"KwarNu Booster: No active window found.");
        return;
    }

    floatingButton =
        [UIButton buttonWithType:UIButtonTypeCustom];

    floatingButton.frame = CGRectMake(20.0, 150.0, 64.0, 64.0);
    floatingButton.backgroundColor =
        [UIColor colorWithRed:0.0
                        green:0.65
                         blue:0.35
                        alpha:0.95];

    floatingButton.layer.cornerRadius = 32.0;
    floatingButton.layer.borderWidth = 1.5;
    floatingButton.layer.borderColor =
        [UIColor whiteColor].CGColor;

    [floatingButton setTitle:@"FPS"
                    forState:UIControlStateNormal];

    floatingButton.titleLabel.font =
        [UIFont boldSystemFontOfSize:13.0];

    [floatingButton addTarget:self
                       action:@selector(toggleMenu)
             forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *pan =
        [[UIPanGestureRecognizer alloc]
            initWithTarget:self
                    action:@selector(handlePan:)];

    [floatingButton addGestureRecognizer:pan];
    [window addSubview:floatingButton];

    menuView = [[UIView alloc]
        initWithFrame:CGRectMake(20.0, 225.0, 260.0, 190.0)];

    menuView.backgroundColor =
        [UIColor colorWithRed:0.05
                        green:0.10
                         blue:0.15
                        alpha:0.96];

    menuView.layer.cornerRadius = 14.0;
    menuView.layer.borderWidth = 1.0;
    menuView.layer.borderColor =
        [UIColor colorWithRed:0.0
                        green:0.85
                         blue:0.45
                        alpha:1.0].CGColor;

    menuView.hidden = YES;

    UILabel *titleLabel = [[UILabel alloc]
        initWithFrame:CGRectMake(10.0, 10.0, 240.0, 25.0)];

    titleLabel.text = @"Kwar Nu Gaming Booster";
    titleLabel.textColor =
        [UIColor colorWithRed:0.2
                        green:1.0
                         blue:0.55
                        alpha:1.0];

    titleLabel.font = [UIFont boldSystemFontOfSize:14.0];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [menuView addSubview:titleLabel];

    fpsLabel = [[UILabel alloc]
        initWithFrame:CGRectMake(15.0, 40.0, 230.0, 25.0)];

    fpsLabel.text = @"FPS: Measuring...";
    fpsLabel.textColor = [UIColor whiteColor];
    fpsLabel.font = [UIFont systemFontOfSize:12.0];
    [menuView addSubview:fpsLabel];

    infoLabel = [[UILabel alloc]
        initWithFrame:CGRectMake(15.0, 68.0, 230.0, 40.0)];

    infoLabel.numberOfLines = 2;
    infoLabel.textColor = [UIColor whiteColor];
    infoLabel.font = [UIFont systemFontOfSize:12.0];
    infoLabel.text = @"RAM Usage: Checking...\nStatus: Ready";
    [menuView addSubview:infoLabel];

    UIButton *refreshButton =
        [UIButton buttonWithType:UIButtonTypeSystem];

    refreshButton.frame =
        CGRectMake(15.0, 115.0, 230.0, 30.0);

    refreshButton.backgroundColor =
        [UIColor colorWithRed:0.0
                        green:0.85
                         blue:0.45
                        alpha:1.0];

    [refreshButton setTitle:@"Refresh Status"
                   forState:UIControlStateNormal];

    [refreshButton setTitleColor:[UIColor blackColor]
                        forState:UIControlStateNormal];

    refreshButton.layer.cornerRadius = 7.0;

    [refreshButton addTarget:self
                      action:@selector(refreshStatus)
            forControlEvents:UIControlEventTouchUpInside];

    [menuView addSubview:refreshButton];

    UIButton *closeButton =
        [UIButton buttonWithType:UIButtonTypeSystem];

    closeButton.frame =
        CGRectMake(15.0, 152.0, 230.0, 27.0);

    [closeButton setTitle:@"Close Menu"
                 forState:UIControlStateNormal];

    [closeButton setTitleColor:[UIColor whiteColor]
                      forState:UIControlStateNormal];

    [closeButton addTarget:self
                    action:@selector(toggleMenu)
          forControlEvents:UIControlEventTouchUpInside];

    [menuView addSubview:closeButton];
    [window addSubview:menuView];

    displayLink =
        [CADisplayLink displayLinkWithTarget:self
                                     selector:@selector(updateTick:)];

    [displayLink addToRunLoop:[NSRunLoop mainRunLoop]
                      forMode:NSRunLoopCommonModes];

    [self refreshStatus];
}

+ (void)handlePan:(UIPanGestureRecognizer *)pan {
    UIView *view = pan.view;
    UIView *parent = view.superview;

    if (view == nil || parent == nil) {
        return;
    }

    CGPoint translation = [pan translationInView:parent];

    CGPoint center = CGPointMake(
        view.center.x + translation.x,
        view.center.y + translation.y
    );

    CGFloat halfWidth = view.bounds.size.width / 2.0;
    CGFloat halfHeight = view.bounds.size.height / 2.0;

    center.x = MAX(halfWidth,
        MIN(parent.bounds.size.width - halfWidth, center.x));

    center.y = MAX(halfHeight,
        MIN(parent.bounds.size.height - halfHeight, center.y));

    view.center = center;

    [pan setTranslation:CGPointMake(0.0, 0.0)
                inView:parent];

    if (menuIsOpen && menuView != nil) {
        menuView.center = CGPointMake(
            center.x,
            center.y + 130.0
        );
    }
}

+ (void)toggleMenu {
    if (menuView == nil) {
        return;
    }

    menuIsOpen = !menuIsOpen;
    menuView.hidden = !menuIsOpen;

    if (menuIsOpen) {
        menuView.center = CGPointMake(
            floatingButton.center.x,
            floatingButton.center.y + 130.0
        );

        [self refreshStatus];
    }
}

+ (void)refreshStatus {
    double ram = [self getMemoryUsage];

    infoLabel.text = [NSString stringWithFormat:
        @"RAM Usage: %.1f MB\nStatus: Monitoring", ram];
}

+ (void)updateTick:(CADisplayLink *)link {
    if (lastTime == 0.0) {
        lastTime = link.timestamp;
        return;
    }

    frameCount++;

    CFTimeInterval elapsed = link.timestamp - lastTime;

    if (elapsed >= 1.0) {
        double fps = (double)frameCount / elapsed;

        frameCount = 0;
        lastTime = link.timestamp;

        NSString *fpsText = [NSString stringWithFormat:
            @"FPS: %.0f", fps];

        fpsLabel.text = fpsText;

        [floatingButton setTitle:
            [NSString stringWithFormat:@"%.0f FPS", fps]
                        forState:UIControlStateNormal];
    }
}

@end
