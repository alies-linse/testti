//
//  APXCommon.h
//  AwemePlus —— 抖音增强（纯净版）
//
//  公共工具：日志、ObjC runtime 方法替换、安全 KVC、ivar 树查找、UI 辅助。
//  本项目不使用 CydiaSubstrate / libhooker / Orion 的任何 API，
//  方法替换全部基于 Objective-C runtime，因此没有第三方 hook 库依赖。
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - 日志

/// 是否输出日志（由设置项控制，默认 YES）
FOUNDATION_EXPORT BOOL APXLogEnabled(void);

#define APXLog(fmt, ...) \
    do { if (APXLogEnabled()) NSLog(@"[AwemePlus] " fmt, ##__VA_ARGS__); } while (0)

#pragma mark - Runtime

/// 替换实例方法的实现，返回原实现（失败返回 NULL）。不做方法交换，
/// 因此不会影响子类；原实现通过 APXOriginalIMP 调用。
FOUNDATION_EXPORT IMP _Nullable APXSwizzleInstance(Class cls, SEL sel, IMP replacement);

/// 替换类方法的实现，返回原实现（失败返回 NULL）。
FOUNDATION_EXPORT IMP _Nullable APXSwizzleClass(Class cls, SEL sel, IMP replacement);

/// 取被替换前的原实现（会沿继承链查找）。
FOUNDATION_EXPORT IMP _Nullable APXOriginalIMP(id receiver, SEL sel);

/// 扫描当前已注册的所有类，返回实现了该实例方法的类。
/// 注意：会遍历全部类，不要在热路径里频繁调用。
FOUNDATION_EXPORT NSArray<Class> *APXClassesRespondingToSelector(SEL sel);

/// 扫描当前已注册的所有类，返回类名包含 needle 的类。
FOUNDATION_EXPORT NSArray<Class> *APXClassesWithNameContaining(NSString *needle);

#pragma mark - 安全取值

/// KVC 取值，任何异常都吞掉并返回 nil。
FOUNDATION_EXPORT id _Nullable APXGet(id _Nullable obj, NSString *key);

/// KVC 设值，返回是否成功。
FOUNDATION_EXPORT BOOL APXSet(id obj, NSString *key, id _Nullable value);

/// 对象的类名（nil 安全）。
FOUNDATION_EXPORT NSString *APXClassName(id _Nullable obj);

/// 对象是否属于「类名以某个前缀开头」的类簇。
FOUNDATION_EXPORT BOOL APXIsKindOfNamedClass(id _Nullable obj, NSArray<NSString *> *classPrefixes);

#pragma mark - ivar 树查找

/// 在对象的 ivar 树里查找「类名以 classPrefixes 之一开头」的对象。
/// maxDepth 建议 2（1 = 只看直接 ivar，2 = 再看一层容器的 ivar）。
/// 这是应对抖音频繁改类名的主要手段：不写死类名，靠结构去找模型。
FOUNDATION_EXPORT id _Nullable APXFindIvar(id _Nullable obj,
                                           NSArray<NSString *> *classPrefixes,
                                           NSUInteger maxDepth);

#pragma mark - UI

/// 取当前 keyWindow；取不到返回 nil（可能还没建好窗口）
FOUNDATION_EXPORT UIWindow * _Nullable APXKeyWindow(void);

/// 取当前最前面的控制器；取不到返回 nil
FOUNDATION_EXPORT UIViewController * _Nullable APXTopViewController(void);

NS_ASSUME_NONNULL_END
