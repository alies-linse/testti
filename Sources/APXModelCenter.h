//
//  APXModelCenter.h
//  AwemePlus
//
//  「当前作品」的采集中心。
//
//  抖音的类名几乎每个版本都在变，所以这里不写死任何类名：
//  启动后扫描所有已注册的类，凡是实现了 setAwemeModel: / setAweme: 之类
//  setter 的类，都挂上我们的记录钩子，把最近一次被设置的模型记下来。
//  找不到时再退化为「从当前界面现场按 ivar 结构抓取」。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface APXModelCenter : NSObject

/// 安装采集钩子 + 定时补挂（抖音的类会陆续注册，所以要多次扫描）
+ (void)start;

/// 记录一个模型（由钩子或现场采集调用）
+ (void)noteModel:(id)model from:(id _Nullable)sender;

/// 取当前作品模型；找不到返回 nil
+ (nullable id)currentModel;

/// 从任意对象（通常是 VC）的 ivar 树里找作品模型
+ (nullable id)harvestFrom:(id)object;

/// 现场采集：从当前最前面的控制器里找
+ (nullable id)harvestFromTopViewController;

/// 模型类名前缀表（提取器共用）
+ (NSArray<NSString *> *)modelClassPrefixes;

@end

NS_ASSUME_NONNULL_END
