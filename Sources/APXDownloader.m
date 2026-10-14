//
//  APXDownloader.m
//  AwemePlus
//
//  只用 NSURLSession 直连抖音 CDN 取文件，不经过任何第三方服务器。
//

#import "APXDownloader.h"
#import "APXCommon.h"
#import "APXPreferences.h"
#import "APXHUD.h"
#import <Photos/Photos.h>

#pragma mark - 内部任务对象

@interface APXDownloadItem : NSObject
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *filename;
@property (nonatomic, assign) BOOL isVideo;
@end

@implementation APXDownloadItem
+ (instancetype)itemWithURL:(NSString *)url filename:(NSString *)filename isVideo:(BOOL)isVideo {
    APXDownloadItem *i = [[APXDownloadItem alloc] init];
    i.url = url;
    i.filename = filename;
    i.isVideo = isVideo;
    return i;
}
@end

#pragma mark -

@implementation APXDownloader

#pragma mark - 环境

static NSString *APXUserAgent(void) {
    static NSString *ua = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *ver = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        ua = [NSString stringWithFormat:@"Aweme/%@ (iPhone; iOS %@; Scale/3.00)",
              ver.length ? ver : @"1.0",
              UIDevice.currentDevice.systemVersion ?: @"0"];
    });
    return ua;
}

static NSURLSession *APXSession(void) {
    static NSURLSession *session = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
        cfg.timeoutIntervalForRequest = 30.0;
        cfg.timeoutIntervalForResource = 600.0;
        cfg.HTTPAdditionalHeaders = @{
            @"User-Agent" : APXUserAgent(),
            @"Referer"    : @"https://www.douyin.com/",
        };
        session = [NSURLSession sessionWithConfiguration:cfg];
    });
    return session;
}

+ (NSString *)downloadDirectory {
    NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    if (!docs.length) docs = NSTemporaryDirectory();
    NSString *dir = [docs stringByAppendingPathComponent:@"AwemePlus"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];
    return dir;
}

#pragma mark - 文件名

+ (NSString *)sanitize:(NSString *)name {
    NSCharacterSet *bad = [NSCharacterSet characterSetWithCharactersInString:@"/\\:*?\"<>|\n\r\t "];
    NSArray *parts = [name componentsSeparatedByCharactersInSet:bad];
    NSString *s = [parts componentsJoinedByString:@"_"];
    return s.length ? s : @"unknown";
}

+ (NSString *)baseNameForInfo:(APXAwemeInfo *)info {
    static NSDateFormatter *fmt = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        fmt = [[NSDateFormatter alloc] init];
        fmt.dateFormat = @"yyyyMMdd_HHmmss";
    });
    NSString *ident = [self sanitize:(info.awemeID.length ? info.awemeID : @"no_id")];
    return [NSString stringWithFormat:@"AwemePlus_%@_%@", ident, [fmt stringFromDate:[NSDate date]]];
}

static NSString *APXExtensionForURL(NSString *url, BOOL isVideo) {
    NSString *noQuery = [[url componentsSeparatedByString:@"?"] firstObject] ?: url;
    NSString *ext = noQuery.pathExtension.lowercaseString;
    NSSet *videoExts = [NSSet setWithArray:@[ @"mp4", @"mov", @"m4v" ]];
    NSSet *imageExts = [NSSet setWithArray:@[ @"jpg", @"jpeg", @"png", @"webp", @"heic", @"tiff" ]];
    if (isVideo && [videoExts containsObject:ext]) return ext;
    if (!isVideo && [imageExts containsObject:ext]) return ext;
    return isVideo ? @"mp4" : @"jpg";
}

/// 音频要单独判：抖音的音乐地址常见 mp3 / m4a，拿不准就按 m4a 存（扩展名不影响播放器识别）
static NSString *APXAudioExtensionForURL(NSString *url) {
    NSString *noQuery = [[url componentsSeparatedByString:@"?"] firstObject] ?: url;
    NSString *ext = noQuery.pathExtension.lowercaseString;
    NSSet *audioExts = [NSSet setWithArray:@[ @"mp3", @"m4a", @"aac", @"wav" ]];
    return [audioExts containsObject:ext] ? ext : @"m4a";
}

+ (NSString *)uniquePathForPath:(NSString *)path {
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return path;
    NSString *dir = path.stringByDeletingLastPathComponent;
    NSString *base = path.lastPathComponent.stringByDeletingPathExtension;
    NSString *ext = path.pathExtension;
    for (NSUInteger i = 1; i < 1000; i++) {
        NSString *candidate = [dir stringByAppendingPathComponent:
                               [NSString stringWithFormat:@"%@_%lu.%@", base, (unsigned long)i, ext]];
        if (![[NSFileManager defaultManager] fileExistsAtPath:candidate]) return candidate;
    }
    return path;
}

#pragma mark - 落盘

+ (NSString *)moveIntoDocumentsFromPath:(NSString *)path filename:(NSString *)filename {
    NSString *dst = [[self downloadDirectory] stringByAppendingPathComponent:filename];
    dst = [self uniquePathForPath:dst];
    NSError *err = nil;
    if ([[NSFileManager defaultManager] moveItemAtPath:path toPath:dst error:&err]) {
        return dst;
    }
    APXLog(@"移入 Documents 失败：%@", err.localizedDescription);
    return nil;
}

/// 写相册前先确保拿到「仅添加」权限。
/// 抖音自己通常会申请过相册权限，但用户可能拒绝过、或从没触发过；
/// 不主动申请的话 performChanges 会直接失败，保存就永远落回沙盒。
+ (void)ensureAddOnlyPhotoAuthorization:(void (^)(BOOL granted))completion {
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelAddOnly];
    if (status == PHAuthorizationStatusAuthorized || status == PHAuthorizationStatusLimited) {
        completion(YES);
        return;
    }
    if (status == PHAuthorizationStatusNotDetermined) {
        [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly
                                                   handler:^(PHAuthorizationStatus newStatus) {
            BOOL ok = (newStatus == PHAuthorizationStatusAuthorized ||
                       newStatus == PHAuthorizationStatusLimited);
            dispatch_async(dispatch_get_main_queue(), ^{ completion(ok); });
        }];
        return;
    }
    completion(NO);   // 用户明确拒绝过，只能在设置里改
}

+ (void)saveToAlbumAtPath:(NSString *)path
                  isVideo:(BOOL)isVideo
                 filename:(NSString *)filename
               completion:(void (^)(BOOL ok))completion {
    [self ensureAddOnlyPhotoAuthorization:^(BOOL granted) {
        if (!granted) {
            APXLog(@"没有相册写入权限，改为保存到沙盒");
            if (completion) completion(NO);
            return;
        }
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            PHAssetCreationRequest *req = [PHAssetCreationRequest creationRequestForAsset];
            PHAssetResourceCreationOptions *opts = [[PHAssetResourceCreationOptions alloc] init];
            opts.originalFilename = filename;
            [req addResourceWithType:(isVideo ? PHAssetResourceTypeVideo : PHAssetResourceTypePhoto)
                             fileURL:[NSURL fileURLWithPath:path]
                             options:opts];
        } completionHandler:^(BOOL success, NSError *error) {
            if (!success) {
                APXLog(@"写入相册失败：%@", error.localizedDescription ?: @"unknown");
            }
            if (completion) completion(success);
        }];
    }];
}

/// 下载完成后决定去向：优先相册，失败或关闭时留在沙盒。
+ (void)persistFileAtPath:(NSString *)path
                     item:(APXDownloadItem *)item
               completion:(void (^)(BOOL ok))completion {
    if ([APXPreferences saveToAlbum]) {
        [self saveToAlbumAtPath:path isVideo:item.isVideo filename:item.filename completion:^(BOOL ok) {
            if (ok) {
                [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
                dispatch_async(dispatch_get_main_queue(), ^{ completion(YES); });
                return;
            }
            NSString *kept = [self moveIntoDocumentsFromPath:path filename:item.filename];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (kept) [APXHUD toast:@"相册保存失败，已存入 Documents/AwemePlus/"];
                completion(kept != nil);
            });
        }];
        return;
    }
    NSString *kept = [self moveIntoDocumentsFromPath:path filename:item.filename];
    dispatch_async(dispatch_get_main_queue(), ^{ completion(kept != nil); });
}

#pragma mark - 单个文件

+ (void)downloadItem:(APXDownloadItem *)item completion:(void (^)(BOOL ok))completion {
    NSURL *url = [NSURL URLWithString:item.url];
    if (!url) {
        dispatch_async(dispatch_get_main_queue(), ^{ completion(NO); });
        return;
    }

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.timeoutInterval = 30.0;

    NSURLSessionDownloadTask *task =
    [APXSession() downloadTaskWithRequest:req
                        completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        if (error || !location) {
            APXLog(@"下载失败 %@：%@", item.filename, error.localizedDescription ?: @"no file");
            dispatch_async(dispatch_get_main_queue(), ^{ completion(NO); });
            return;
        }
        // 临时文件名加 UUID 前缀：避免同批次里两个同名文件互相覆盖（扩展名保留，PhotoKit 靠它判类型）
        NSString *tmpName = [NSString stringWithFormat:@"%@_%@", [NSUUID UUID].UUIDString, item.filename];
        NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:tmpName];
        NSFileManager *fm = [NSFileManager defaultManager];
        [fm removeItemAtPath:tmp error:NULL];
        NSError *moveErr = nil;
        if (![fm moveItemAtURL:location toURL:[NSURL fileURLWithPath:tmp] error:&moveErr]) {
            APXLog(@"临时文件转移失败:%@", moveErr.localizedDescription);
            dispatch_async(dispatch_get_main_queue(), ^{ completion(NO); });
            return;
        }
        [self persistFileAtPath:tmp item:item completion:completion];
    }];
    [task resume];
}

#pragma mark - 候选地址重试（视频 / 音乐）

+ (void)downloadFirstAvailable:(NSArray<NSString *> *)urls
                      filename:(NSString *)filename
                       isVideo:(BOOL)isVideo
                         index:(NSUInteger)index
                    completion:(void (^)(BOOL ok))completion {
    if (index >= urls.count) { completion(NO); return; }
    APXDownloadItem *item = [APXDownloadItem itemWithURL:urls[index] filename:filename isVideo:isVideo];
    APXLog(@"尝试地址 %lu/%lu", (unsigned long)(index + 1), (unsigned long)urls.count);
    [self downloadItem:item completion:^(BOOL ok) {
        if (ok) { completion(YES); return; }
        [self downloadFirstAvailable:urls filename:filename isVideo:isVideo index:index + 1 completion:completion];
    }];
}

#pragma mark - 批量（图集）

+ (void)downloadItems:(NSArray<APXDownloadItem *> *)items
                index:(NSUInteger)index
              success:(NSUInteger)success
               failed:(NSUInteger)failed
           completion:(void (^)(void))completion {
    if (index >= items.count) {
        [APXHUD toast:[NSString stringWithFormat:@"完成：成功 %lu / 失败 %lu",
                       (unsigned long)success, (unsigned long)failed] duration:2.8];
        if (completion) completion();
        return;
    }
    [self downloadItem:items[index] completion:^(BOOL ok) {
        [self downloadItems:items
                      index:index + 1
                    success:success + (ok ? 1 : 0)
                     failed:failed + (ok ? 0 : 1)
                 completion:completion];
    }];
}

#pragma mark - 对外入口

+ (void)downloadInfo:(APXAwemeInfo *)info mode:(APXDownloadMode)mode {
    if (!info) { [APXHUD toast:@"没有取到作品信息"]; return; }

    NSString *base = [self baseNameForInfo:info];

    if (mode == APXDownloadModeVideo) {
        if (!info.videoURLs.count) { [APXHUD toast:@"未找到视频地址"]; return; }
        NSString *filename = [base stringByAppendingFormat:@".%@", APXExtensionForURL(info.videoURLs.firstObject, YES)];
        [APXHUD toast:@"开始下载视频…"];
        [self downloadFirstAvailable:info.videoURLs
                            filename:filename
                             isVideo:YES
                               index:0
                          completion:^(BOOL ok) {
            [APXHUD toast:(ok ? @"视频已保存" : @"视频下载失败，可换个作品再试") duration:2.6];
        }];
        return;
    }

    if (mode == APXDownloadModeMusic) {
        if (!info.musicURL.length) { [APXHUD toast:@"该作品没有可下载的背景音乐"]; return; }
        NSString *filename = [base stringByAppendingFormat:@"_music.%@", APXAudioExtensionForURL(info.musicURL)];
        [APXHUD toast:@"开始下载音频…"];
        [self downloadFirstAvailable:@[ info.musicURL ]
                            filename:filename
                             isVideo:NO
                               index:0
                          completion:^(BOOL ok) {
            [APXHUD toast:(ok ? @"音频已保存" : @"音频下载失败") duration:2.6];
        }];
        return;
    }

    // 图集
    if (!info.imageURLs.count) { [APXHUD toast:@"该作品没有图集"]; return; }
    NSMutableArray<APXDownloadItem *> *items = [NSMutableArray array];
    [info.imageURLs enumerateObjectsUsingBlock:^(NSString *url, NSUInteger idx, BOOL *stop) {
        NSString *ext = APXExtensionForURL(url, NO);
        NSString *filename = [base stringByAppendingFormat:@"_%02lu.%@", (unsigned long)(idx + 1), ext];
        [items addObject:[APXDownloadItem itemWithURL:url filename:filename isVideo:NO]];
    }];
    [APXHUD toast:[NSString stringWithFormat:@"开始下载 %lu 张图片…", (unsigned long)items.count]];
    [self downloadItems:items index:0 success:0 failed:0 completion:nil];
}

@end
