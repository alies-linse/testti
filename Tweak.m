//
//  Tweak.m
//  AwemePlus —— 抖音增强（纯净版）
//
//  入口。只用 __attribute__((constructor))，不依赖 CydiaSubstrate / logos。
//  这里没有任何网络请求、授权校验、设备信息采集。
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "APXCommon.h"
#import "APXPreferences.h"
#import "APXModelCenter.h"
#import "APXLongPress.h"
#import "APXMenu.h"

#pragma mark - 环境判断

static BOOL APXIsTargetApp(void) {
    static BOOL result = NO;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *bundleID = [NSBundle mainBundle].bundleIdentifier ?: @"";

        // 抖音 / 抖音极速版
        if ([bundleID isEqualToString:@"com.ss.iphone.ugc.Aweme"] ||
            [bundleID isEqualToString:@"com.ss.iphone.ugc.aweme.lite"]) {
            result = YES;
            return;
        }

        // 兜底一：抖音系的其他 bundle id 变体
        if ([bundleID hasPrefix:@"com.ss.iphone.ugc."]) {
            result = YES;
            return;
        }

        // 兜底二：bundle id 拿不到时看可执行文件名
        NSString *executable = [NSProcessInfo processInfo].arguments.firstObject.lastPathComponent ?: @"";
        if ([executable isEqualToString:@"Aweme"] || [executable hasPrefix:@"Aweme"]) {
            result = YES;
        }
    });
    return result;
}

#pragma mark - 安装

static void APXInstallEverything(void) {
    if (![APXPreferences enabled]) {
        APXLog(@"总开关已关闭，不安装任何 hook");
        return;
    }
    [APXModelCenter start];                          // 采集当前作品模型
    [APXLongPress install];                          // 长按面板下载按钮
    [[APXMenuPresenter shared] installGesture];      // 双指双击菜单
    APXLog(@"初始化完成（全部逻辑本地运行，无远端配置）");
}

#pragma mark - 入口

__attribute__((constructor))
static void APXInitialize(void) {
    @autoreleasepool {
        if (!APXIsTargetApp()) return;   // 只在抖音里工作

        APXLog(@"已载入：%@ (%@)",
               [NSBundle mainBundle].bundleIdentifier ?: @"?",
               [NSBundle mainBundle].infoDictionary[@"CFBundleShortVersionString"] ?: @"?");

        // 主路径：抖音启动完成后再装 hook（此时业务类才注册得差不多）
        [[NSNotificationCenter defaultCenter]
         addObserverForName:UIApplicationDidFinishLaunchingNotification
                     object:nil
                      queue:[NSOperationQueue mainQueue]
                 usingBlock:^(NSNotification *note) {
            APXInstallEverything();
        }];

        // 进入前台时补挂（窗口可能被重建；也可能是用户在设置里刚把总开关打开）
        // 所有安装步骤都是幂等的，重复调用没有副作用。
        [[NSNotificationCenter defaultCenter]
         addObserverForName:UIApplicationDidBecomeActiveNotification
                     object:nil
                      queue:[NSOperationQueue mainQueue]
                 usingBlock:^(NSNotification *note) {
            APXInstallEverything();
        }];

        // 兜底：有的场景下 didFinishLaunching 通知早于本 dylib 装载
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            APXInstallEverything();
        });
    }
}
