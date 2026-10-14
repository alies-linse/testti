//
//  APXMenu.h
//  AwemePlus
//
//  双指双击呼出的功能菜单（原插件的主力入口，沿用同一个手势习惯）。
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface APXMenuPresenter : NSObject <UIGestureRecognizerDelegate>

+ (instancetype)shared;

/// 往当前 keyWindow 挂手势（幂等；窗口重建后可重复调用）
- (void)installGesture;

/// 主动弹出菜单
- (void)presentMenu;

@end

NS_ASSUME_NONNULL_END
