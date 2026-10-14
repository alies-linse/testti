//
//  APXPreferences.m
//  AwemePlus
//

#import "APXPreferences.h"

NSString * const APXDefaultsSuite = @"com.local.awemeplus";

static NSString * const kAPXKeyEnabled        = @"apx_enabled";
static NSString * const kAPXKeyGesture        = @"apx_gesture_menu";
static NSString * const kAPXKeyLongPress      = @"apx_longpress_button";
static NSString * const kAPXKeySaveToAlbum    = @"apx_save_to_album";
static NSString * const kAPXKeyPreferHD       = @"apx_prefer_hd";
static NSString * const kAPXKeyVerbose        = @"apx_verbose_log";

@implementation APXPreferences

+ (NSUserDefaults *)defaults {
    // 用 standard defaults 即可：宿主 App 就是抖音，配置跟着它自己的沙盒走。
    return [NSUserDefaults standardUserDefaults];
}

+ (BOOL)boolForKey:(NSString *)key defaultValue:(BOOL)def {
    NSUserDefaults *d = [self defaults];
    if ([d objectForKey:key] == nil) return def;
    return [d boolForKey:key];
}

+ (void)setBool:(BOOL)value forKey:(NSString *)key {
    [[self defaults] setBool:value forKey:key];
    [[self defaults] synchronize];
}

+ (BOOL)enabled            { return [self boolForKey:kAPXKeyEnabled     defaultValue:YES]; }
+ (BOOL)gestureMenuEnabled { return [self boolForKey:kAPXKeyGesture     defaultValue:YES]; }
+ (BOOL)longPressButtonEnabled { return [self boolForKey:kAPXKeyLongPress defaultValue:YES]; }
+ (BOOL)saveToAlbum        { return [self boolForKey:kAPXKeySaveToAlbum defaultValue:YES]; }
+ (BOOL)preferHD           { return [self boolForKey:kAPXKeyPreferHD    defaultValue:YES]; }
+ (BOOL)verboseLogging     { return [self boolForKey:kAPXKeyVerbose     defaultValue:YES]; }

+ (NSArray<NSArray<NSString *> *> *)settingItems {
    return @[
        @[ kAPXKeyEnabled,     @"启用 AwemePlus",   @"总开关，关闭后不干预抖音任何行为" ],
        @[ kAPXKeyGesture,     @"双指双击菜单",     @"在抖音任意界面用两根手指双击屏幕呼出功能菜单" ],
        @[ kAPXKeyLongPress,   @"长按面板下载按钮", @"长按视频弹出的原生面板上加一个「无水印下载」按钮" ],
        @[ kAPXKeySaveToAlbum, @"保存到相册",       @"关闭后只保存到抖音沙盒 Documents/AwemePlus/" ],
        @[ kAPXKeyPreferHD,    @"优先高清",         @"下载地址里的低码率参数替换为 1080p" ],
        @[ kAPXKeyVerbose,     @"详细日志",         @"输出 [AwemePlus] 日志，可用 idevicesyslog 查看" ],
    ];
}

@end
