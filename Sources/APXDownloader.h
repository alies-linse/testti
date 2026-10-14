//
//  APXDownloader.h
//  AwemePlus
//

#import <Foundation/Foundation.h>
#import "APXExtractor.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, APXDownloadMode) {
    APXDownloadModeVideo = 0,
    APXDownloadModeImages,
    APXDownloadModeMusic,
};

@interface APXDownloader : NSObject

/// 下载并保存。视频/音乐会在多个候选地址里自动重试，图集会逐个下载。
+ (void)downloadInfo:(APXAwemeInfo *)info mode:(APXDownloadMode)mode;

/// 沙盒里的保存目录：<Documents>/AwemePlus
+ (NSString *)downloadDirectory;

@end

NS_ASSUME_NONNULL_END
