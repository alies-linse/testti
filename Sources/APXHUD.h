//
//  APXHUD.h
//  AwemePlus
//
//  极简 toast：不引入任何 UI 库，直接用 UILabel 挂在 keyWindow 上。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface APXHUD : NSObject

/// 主线程安全，可在任意线程调用。
+ (void)toast:(NSString *)message;
+ (void)toast:(NSString *)message duration:(NSTimeInterval)duration;

@end

NS_ASSUME_NONNULL_END
