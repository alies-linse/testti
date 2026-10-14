//
//  APXLongPress.h
//  AwemePlus
//
//  在抖音原生的「长按视频」面板上，追加一个「无水印下载」按钮。
//
//  实现思路刻意避开了解析面板内部数据模型（各版本差异极大）：
//  只监听「有长按面板被 present / addChild」，然后在它的视图上贴一个自己的按钮。
//  面板内部结构怎么变都不影响这个按钮存在，最多是位置需要微调。
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface APXLongPress : NSObject

/// 安装面板监听
+ (void)install;

/// 判断一个控制器是不是长按面板
+ (BOOL)looksLikeLongPressPanel:(nullable UIViewController *)vc;

/// 往面板上贴按钮（幂等，重复调用只会有一个）
+ (void)attachButtonToPanel:(UIViewController *)panel;

@end

NS_ASSUME_NONNULL_END
