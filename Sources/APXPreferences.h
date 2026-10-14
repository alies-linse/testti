//
//  APXPreferences.h
//  AwemePlus
//
//  全部配置都存在本机 NSUserDefaults 里，不联网、不上报、不校验。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const APXDefaultsSuite;   // 预留：可换成独立 suite

@interface APXPreferences : NSObject

/// 总开关（关闭后所有 hook 逻辑直接放行）
+ (BOOL)enabled;

/// 双指双击呼出功能菜单
+ (BOOL)gestureMenuEnabled;

/// 在抖音原生长按面板上追加「无水印下载」按钮
+ (BOOL)longPressButtonEnabled;

/// 下载完成后保存到相册（关闭则只存到 App 沙盒 Documents）
+ (BOOL)saveToAlbum;

/// 优先请求 1080p（下载地址里把低码率 ratio 替换为 1080p）
+ (BOOL)preferHD;

/// 详细日志
+ (BOOL)verboseLogging;

+ (void)setBool:(BOOL)value forKey:(NSString *)key;
+ (BOOL)boolForKey:(NSString *)key defaultValue:(BOOL)def;

/// 全部键名（设置界面遍历用）
+ (NSArray<NSArray<NSString *> *> *)settingItems;   // @[ @[key, 标题, 说明], ... ]

@end

NS_ASSUME_NONNULL_END
