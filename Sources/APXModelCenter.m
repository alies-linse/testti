//
//  APXModelCenter.m
//  AwemePlus
//

#import "APXModelCenter.h"
#import "APXCommon.h"
#import "APXPreferences.h"
#import <os/lock.h>

static id        gLastModel      = nil;   // ARC 下静态变量默认 __strong
static CFAbsoluteTime gLastModelTime = 0;
static NSMutableSet<NSString *> *gHookedKeys = nil;
static NSUInteger gHookCount = 0;
static os_unfair_lock gHookedKeysLock = OS_UNFAIR_LOCK_INIT;

/// 记录有效窗口：超过这个时间没用新模型覆盖，就认为它已经不是当前屏幕上的作品了。
static const CFTimeInterval kAPXModelFreshSeconds = 120.0;

@implementation APXModelCenter

#pragma mark - 类名前缀

+ (NSArray<NSString *> *)modelClassPrefixes {
    // 抖音各版本用过/仍在用的作品模型类名前缀。
    // 采集时按顺序匹配，命中即返回。
    return @[
        @"AWEAwemeModel",
        @"AwemeModel",
        @"AWEVideoModel",
        @"AWEImageAlbumModel",
        @"AWEPhotoModel",
        @"AWEImageModel",
    ];
}

#pragma mark - 钩子

/// setter 的替换实现：先记录，再调用原实现，完全不改变原行为。
static void APXHook_setAwemeModel(id self, SEL _cmd, id model) {
    if (model) {
        [APXModelCenter noteModel:model from:self];
    }
    IMP orig = APXOriginalIMP(self, _cmd);
    if (orig) {
        ((void (*)(id, SEL, id))orig)(self, _cmd, model);
    }
}

+ (void)installHooks {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gHookedKeys = [NSMutableSet set];
    });

    // 这几个 setter 覆盖了绝大多数版本的「作品模型绑定」入口。
    // 不hook setModel: —— 那个太泛，会挂到大量无关类上。
    NSArray<NSString *> *setterNames = @[ @"setAwemeModel:", @"setAweme:", @"setCurrentAweme:" ];

    NSUInteger installed = 0;
    for (NSString *setterName in setterNames) {
        SEL sel = NSSelectorFromString(setterName);
        if (!sel) continue;
        for (Class cls in APXClassesRespondingToSelector(sel)) {
            // 继承而来的方法已经被父类挂过了：跳过，避免重复记账与虚高的计数
            Method existing = class_getInstanceMethod(cls, sel);
            if (existing && method_getImplementation(existing) == (IMP)APXHook_setAwemeModel) continue;

            NSString *key = [NSString stringWithFormat:@"%s|%@", class_getName(cls), setterName];
            // 目前所有调用点都在主队列上，但这条不变式不该靠"记得"来维持，加锁更省心
            os_unfair_lock_lock(&gHookedKeysLock);
            BOOL already = [gHookedKeys containsObject:key];
            if (!already) [gHookedKeys addObject:key];
            os_unfair_lock_unlock(&gHookedKeysLock);
            if (already) continue;

            if (APXSwizzleInstance(cls, sel, (IMP)APXHook_setAwemeModel)) {
                installed++;
            }
        }
    }
    if (installed > 0) {
        gHookCount += installed;
        APXLog(@"模型采集钩子：本次新挂载 %lu 个（累计 %lu）", (unsigned long)installed, (unsigned long)gHookCount);
    }
}

+ (void)start {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // 抖音启动后才陆续注册业务类，所以分几个时间点补挂。
        NSArray<NSNumber *> *delays = @[ @2.0, @6.0, @15.0, @40.0 ];
        for (NSNumber *d in delays) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(d.doubleValue * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                if (![APXPreferences enabled]) return;
                [self installHooks];
            });
        }
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
            if (![APXPreferences enabled]) return;
            [self installHooks];
        }];

        // 退到后台时松开最近一次模型：它是强引用，会把一个作品对象图（含媒体信息）一直钉在内存里。
        // 下次前台重新采集即可，对使用没有影响。
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
            @synchronized (self) {
                gLastModel = nil;
                gLastModelTime = 0;
            }
        }];
    });
}

#pragma mark - 记录 / 读取

+ (void)noteModel:(id)model from:(id)sender {
    if (!model) return;
    @synchronized (self) {
        gLastModel = model;
        gLastModelTime = CFAbsoluteTimeGetCurrent();
    }
}

+ (id)currentModel {
    id model = nil;
    CFAbsoluteTime t = 0;
    @synchronized (self) {
        model = gLastModel;
        t = gLastModelTime;
    }

    BOOL fresh = (model != nil) && ((CFAbsoluteTimeGetCurrent() - t) < kAPXModelFreshSeconds);
    if (fresh) return model;

    // 记录过期了：现场抓一次；抓不到就老实返回 nil，绝不拿一个很可能已经不是当前屏幕上的作品去下载。
    id live = [self harvestFromTopViewController];
    if (live) return live;

    return nil;
}

#pragma mark - 现场采集

+ (id)harvestFromTopViewController {
    UIViewController *vc = APXTopViewController();
    if (!vc) return nil;
    id model = [self harvestFrom:vc];
    if (!model) {
        // 再试一层：有些面板把模型放在 presentedViewController 上
        UIViewController *presented = vc.presentedViewController;
        if (presented) model = [self harvestFrom:presented];
    }
    return model;
}

+ (id)harvestFrom:(id)object {
    if (!object) return nil;
    id model = APXFindIvar(object, [self modelClassPrefixes], 2);
    if (model) {
        APXLog(@"现场采集到模型：%@（来自 %@）", APXClassName(model), APXClassName(object));
        [self noteModel:model from:object];
    }
    return model;
}

@end
