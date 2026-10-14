//
//  APXHUD.m
//  AwemePlus
//

#import "APXHUD.h"
#import "APXCommon.h"

@implementation APXHUD

+ (void)toast:(NSString *)message {
    [self toast:message duration:2.2];
}

+ (void)toast:(NSString *)message duration:(NSTimeInterval)duration {
    if (!message.length) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = APXKeyWindow();
        if (!window) return;

        UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
        label.text = message;
        label.numberOfLines = 0;
        label.textAlignment = NSTextAlignmentCenter;
        label.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        label.textColor = UIColor.whiteColor;
        label.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.82];
        label.layer.cornerRadius = 10.0;
        label.layer.masksToBounds = YES;
        label.userInteractionEnabled = NO;

        CGSize maxSize = CGSizeMake(MAX(160.0, window.bounds.size.width - 96.0), CGFLOAT_MAX);
        CGRect textRect = [message boundingRectWithSize:maxSize
                                                options:NSStringDrawingUsesLineFragmentOrigin
                                             attributes:@{ NSFontAttributeName: label.font }
                                                context:nil];
        CGFloat width = MIN(ceil(textRect.size.width) + 34.0, maxSize.width + 34.0);
        CGFloat height = ceil(textRect.size.height) + 26.0;
        CGFloat maxHeight = window.bounds.size.height * 0.7;
        if (height > maxHeight) height = maxHeight;   // 极端长文本时截断，避免超出屏幕
        label.frame = CGRectMake((window.bounds.size.width - width) / 2.0,
                                 window.bounds.size.height * 0.70,
                                 width, height);
        label.alpha = 0.0;
        [window addSubview:label];

        [UIView animateWithDuration:0.16 animations:^{
            label.alpha = 1.0;
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.28
                                  delay:MAX(0.4, duration)
                                options:UIViewAnimationOptionAllowUserInteraction
                             animations:^{ label.alpha = 0.0; }
                             completion:^(BOOL done) { [label removeFromSuperview]; }];
        }];
    });
}

@end
