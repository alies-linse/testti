//
//  APXLongPress.m
//  AwemePlus
//

#import "APXLongPress.h"
#import "APXCommon.h"
#import "APXPreferences.h"
#import "APXModelCenter.h"
#import "APXExtractor.h"
#import "APXDownloader.h"
#import "APXHUD.h"

static const NSInteger kAPXButtonTag = 0x41504C58;   // 'APLX'

// 兜底保存的原实现。理论上 APXOriginalIMP 一定能查到（我们就是在 UIViewController
// 这一层换的实现），但 present 是全局高频路径 —— 万一查不到就绝不能什么都不做，
// 否则会连带把整个 App 的页面弹出全部搞坏。有这份兜底就只是退化成"不插按钮"。
static IMP gAPXOrigPresent = NULL;
static IMP gAPXOrigAddChild = NULL;

// C 函数必须先声明后使用（hook 实现放在文件后半部分）
static void APXHook_presentViewController(id self, SEL _cmd, UIViewController *vc, BOOL animated, void (^completion)(void));
static void APXHook_addChildViewController(id self, SEL _cmd, UIViewController *child);

@interface APXLongPress ()
+ (void)handleCandidate:(UIViewController *)vc;
+ (void)downloadButtonTapped:(UIButton *)sender;
@end

@implementation APXLongPress

#pragma mark - 面板判定

+ (BOOL)looksLikeLongPressPanel:(UIViewController *)vc {
    if (!vc) return NO;
    NSString *name = APXClassName(vc);
    if (!name.length) return NO;
    return [name containsString:@"LongPressPanel"]
        || [name containsString:@"LongPress"]
        || [name containsString:@"longPressPanel"];
}

#pragma mark - 安装

+ (void)install {
    Class vcc = [UIViewController class];
    if (!gAPXOrigPresent) {
        gAPXOrigPresent = APXSwizzleInstance(vcc,
                                             @selector(presentViewController:animated:completion:),
                                             (IMP)APXHook_presentViewController);
        if (!gAPXOrigPresent) APXLog(@"presentViewController 原实现缺失，本次不挂该 hook");
    }
    if (!gAPXOrigAddChild) {
        gAPXOrigAddChild = APXSwizzleInstance(vcc,
                                              @selector(addChildViewController:),
                                              (IMP)APXHook_addChildViewController);
        if (!gAPXOrigAddChild) APXLog(@"addChildViewController 原实现缺失，本次不挂该 hook");
    }
    APXLog(@"长按面板监听已安装（present=%p addChild=%p）",
           (void *)gAPXOrigPresent, (void *)gAPXOrigAddChild);
}

/// present 的替换实现：先走原逻辑，再检查被 present 的是不是长按面板。
static void APXHook_presentViewController(id self, SEL _cmd, UIViewController *vc, BOOL animated, void (^completion)(void)) {
    IMP orig = APXOriginalIMP(self, _cmd) ?: gAPXOrigPresent;
    if (orig) {
        ((void (*)(id, SEL, id, BOOL, id))orig)(self, _cmd, vc, animated, completion);
    }
    [APXLongPress handleCandidate:vc];
}

/// addChildViewController 的替换实现：覆盖面板作为子控制器挂载的情况。
static void APXHook_addChildViewController(id self, SEL _cmd, UIViewController *child) {
    IMP orig = APXOriginalIMP(self, _cmd) ?: gAPXOrigAddChild;
    if (orig) {
        ((void (*)(id, SEL, id))orig)(self, _cmd, child);
    }
    [APXLongPress handleCandidate:child];
}

+ (void)handleCandidate:(UIViewController *)vc {
    if (![APXPreferences enabled]) return;
    if (![APXPreferences longPressButtonEnabled]) return;
    if (![self looksLikeLongPressPanel:vc]) return;

    APXLog(@"检测到长按面板：%@", APXClassName(vc));

    // 面板可能还要等一会才完成布局和模型绑定，稍后再贴按钮 + 采集模型
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.30 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        // 面板本身往往就持有当前作品模型，这是最可靠的采集点
        [APXModelCenter harvestFrom:vc];
        [self attachButtonToPanel:vc];
    });
}

#pragma mark - 按钮

+ (void)attachButtonToPanel:(UIViewController *)panel {
    UIView *host = panel.view;
    if (!host) return;
    if ([host viewWithTag:kAPXButtonTag]) return;   // 已经贴过了

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tag = kAPXButtonTag;
    [button setTitle:@"⬇︎ 无水印下载" forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.backgroundColor = [UIColor colorWithRed:0.98 green:0.24 blue:0.36 alpha:0.94];
    button.layer.cornerRadius = 16.0;
    button.layer.shadowColor = UIColor.blackColor.CGColor;
    button.layer.shadowOpacity = 0.25;
    button.layer.shadowRadius = 4.0;
    button.layer.shadowOffset = CGSizeMake(0, 1);
    button.contentEdgeInsets = UIEdgeInsetsMake(8, 16, 8, 16);
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button addTarget:self action:@selector(downloadButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

    [host addSubview:button];
    [NSLayoutConstraint activateConstraints:@[
        [button.trailingAnchor constraintEqualToAnchor:host.safeAreaLayoutGuide.trailingAnchor constant:-14.0],
        [button.bottomAnchor constraintEqualToAnchor:host.safeAreaLayoutGuide.bottomAnchor constant:-90.0],
        // contentEdgeInsets 在 iOS 15 上已废弃，如果哪天它不生效，这条兜底保证按钮不会缩成一条
        [button.heightAnchor constraintGreaterThanOrEqualToConstant:34.0],
    ]];

    APXLog(@"已向面板注入下载按钮（宿主 %@）", APXClassName(panel));
}

+ (void)downloadButtonTapped:(UIButton *)sender {
    UIViewController *panel = APXTopViewController();
    id model = [APXModelCenter currentModel];
    if (!model) model = [APXModelCenter harvestFrom:panel];
    if (!model) {
        [APXHUD toast:@"没有识别到当前作品，请先点开一个视频再试"];
        return;
    }
    APXAwemeInfo *info = [APXExtractor infoFromModel:model];
    if (!info) {
        [APXHUD toast:@"解析作品信息失败"];
        return;
    }
    if (info.hasImages) {
        [APXDownloader downloadInfo:info mode:APXDownloadModeImages];
    } else if (info.hasVideo) {
        [APXDownloader downloadInfo:info mode:APXDownloadModeVideo];
    } else {
        [APXHUD toast:@"这个作品没有可下载的内容"];
    }
}

@end
