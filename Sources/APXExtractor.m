//
//  APXExtractor.m
//  AwemePlus
//

#import "APXExtractor.h"
#import "APXCommon.h"
#import "APXPreferences.h"

@interface APXExtractor ()
+ (NSString *)synthesizedPlayURLWithVideoID:(NSString *)videoID preferHD:(BOOL)preferHD;
@end

#pragma mark - 结果对象

@implementation APXAwemeInfo

- (BOOL)hasVideo  { return self.videoURLs.count > 0; }
- (BOOL)hasImages { return self.imageURLs.count > 0; }

- (NSString *)summary {
    NSMutableString *s = [NSMutableString string];
    [s appendFormat:@"model=%@", self.sourceClassName ?: @"?"];
    if (self.awemeID.length) [s appendFormat:@" id=%@", self.awemeID];
    [s appendFormat:@" 视频源=%lu", (unsigned long)self.videoURLs.count];
    if (self.imageURLs.count) [s appendFormat:@" 图片=%lu", (unsigned long)self.imageURLs.count];
    if (self.musicURL.length) [s appendString:@" 有音乐"];
    if (self.desc.length) [s appendFormat:@" 文案=%lu字", (unsigned long)self.desc.length];
    return s;
}

@end

#pragma mark - 地址提取

/// 从一个「URL 容器」里取第一条 http 地址。
/// 抖音的 URL 容器长得五花八门：AWENetworkURLModel（有 urlList）、
/// 直接是 NSString、NSArray、或者嵌了一层 url/playUrl。
static NSString *APXURLStringFrom(id urlModel) {
    if (!urlModel) return nil;

    if ([urlModel isKindOfClass:[NSString class]]) {
        NSString *s = (NSString *)urlModel;
        return [s hasPrefix:@"http"] ? s : nil;
    }
    if ([urlModel isKindOfClass:[NSArray class]]) {
        for (id item in (NSArray *)urlModel) {
            NSString *s = APXURLStringFrom(item);
            if (s.length) return s;
        }
        return nil;
    }
    if ([urlModel isKindOfClass:[NSURL class]]) {
        NSString *s = [(NSURL *)urlModel absoluteString];
        return [s hasPrefix:@"http"] ? s : nil;
    }

    // 常见的数组容器键
    for (NSString *key in @[ @"urlList", @"urls", @"url_list", @"originUrlList" ]) {
        id list = APXGet(urlModel, key);
        if (list) {
            NSString *s = APXURLStringFrom(list);
            if (s.length) return s;
        }
    }
    // 常见的单值键
    for (NSString *key in @[ @"url", @"URL", @"src", @"playUrl", @"uri" ]) {
        id v = APXGet(urlModel, key);
        if (v) {
            NSString *s = APXURLStringFrom(v);
            if (s.length) return s;
        }
    }
    return nil;
}

/// 按候选键顺序，从容器里取第一个非空地址
static NSString *APXFirstURL(id container, NSArray<NSString *> *keys) {
    if (!container) return nil;
    for (NSString *key in keys) {
        NSString *s = APXURLStringFrom(APXGet(container, key));
        if (s.length) return s;
    }
    return nil;
}

#pragma mark - 提取器

@implementation APXExtractor

+ (NSString *)cleanDownloadURL:(NSString *)url preferHD:(BOOL)preferHD {
    if (!url.length) return url;

    NSString *s = url;
    // 有些地址里的 & 被转义成了 \u0026
    s = [s stringByReplacingOccurrencesOfString:@"\\u0026" withString:@"&"];
    // 核心：把水印开关关掉
    s = [s stringByReplacingOccurrencesOfString:@"watermark=1" withString:@"watermark=0"];
    // 老域名下的带水印路径
    s = [s stringByReplacingOccurrencesOfString:@"/playwm/" withString:@"/play/"];
    // 提升码率
    if (preferHD) {
        for (NSString *low in @[ @"ratio=240p", @"ratio=360p", @"ratio=480p", @"ratio=540p", @"ratio=720p" ]) {
            s = [s stringByReplacingOccurrencesOfString:low withString:@"ratio=1080p"];
        }
    }
    return s;
}

+ (NSString *)synthesizedPlayURLWithVideoID:(NSString *)videoID preferHD:(BOOL)preferHD {
    if (!videoID.length) return nil;
    NSString *ratio = preferHD ? @"1080p" : @"720p";
    return [NSString stringWithFormat:
            @"https://www.douyin.com/aweme/v1/play/?video_id=%@&ratio=%@&line=0",
            videoID, ratio];
}

+ (APXAwemeInfo *)infoFromModel:(id)model {
    if (!model) return nil;

    APXAwemeInfo *info = [[APXAwemeInfo alloc] init];
    info.sourceClassName = APXClassName(model);
    BOOL preferHD = [APXPreferences preferHD];

    // ---- 作品 ID ----
    for (NSString *key in @[ @"awemeId", @"aweme_id", @"itemID", @"itemId", @"groupID", @"group_id" ]) {
        id v = APXGet(model, key);
        if ([v isKindOfClass:[NSString class]] && [(NSString *)v length]) { info.awemeID = v; break; }
        if ([v isKindOfClass:[NSNumber class]]) { info.awemeID = [(NSNumber *)v stringValue]; break; }
    }

    // ---- 文案 ----
    id desc = APXGet(model, @"desc");
    if ([desc isKindOfClass:[NSString class]] && [(NSString *)desc length]) {
        info.desc = desc;
    }

    // ---- 视频容器：模型本身可能是 aweme，也可能是 video ----
    id video = APXGet(model, @"video");
    id videoContainer = video ?: model;

    // ---- 图集 ----
    id images = APXGet(model, @"images");
    if ([images isKindOfClass:[NSArray class]] && [(NSArray *)images count] > 0) {
        NSMutableArray<NSString *> *urls = [NSMutableArray array];
        for (id img in (NSArray *)images) {
            NSString *u = APXFirstURL(img, @[ @"originUrl", @"downloadUrl", @"urlList", @"displayImage", @"url" ]);
            if (!u.length) u = APXURLStringFrom(img);
            if (u.length) [urls addObject:u];
        }
        if (urls.count) {
            info.imageURLs = urls;
            info.isAlbum = YES;
        }
    }

    // ---- 视频地址：按「越可能无水印越靠前」的顺序试 ----
    NSMutableArray<NSString *> *videoURLs = [NSMutableArray array];
    NSArray<NSString *> *videoKeys = @[
        @"playAddr",          // 播放地址，通常无水印
        @"playAddrH264",
        @"playAddrBytevc1",
        @"playApi",
        @"downloadAddr",      // 下载地址，通常带水印（放在后面兜底）
    ];
    for (NSString *key in videoKeys) {
        NSString *raw = APXURLStringFrom(APXGet(videoContainer, key));
        if (!raw.length) continue;
        NSString *clean = [self cleanDownloadURL:raw preferHD:preferHD];
        if (clean.length && ![videoURLs containsObject:clean]) [videoURLs addObject:clean];
    }

    // 视频 ID 兜底：直接用官方播放接口拼一个
    if (videoURLs.count == 0) {
        NSString *vid = nil;
        for (NSString *key in @[ @"videoId", @"videoID", @"uri", @"vid" ]) {
            id v = APXGet(videoContainer, key);
            if ([v isKindOfClass:[NSString class]] && [(NSString *)v length]) { vid = v; break; }
        }
        NSString *synth = [self synthesizedPlayURLWithVideoID:vid preferHD:preferHD];
        if (synth.length) [videoURLs addObject:synth];
    }

    // 如果 videoContainer 本身就是个 URL 容器（传进来的就是地址模型）
    if (videoURLs.count == 0) {
        NSString *raw = APXURLStringFrom(videoContainer);
        if (raw.length) [videoURLs addObject:[self cleanDownloadURL:raw preferHD:preferHD]];
    }

    info.videoURLs = videoURLs;

    // ---- 背景音乐 ----
    id music = APXGet(model, @"music");
    if (music) {
        NSString *u = APXFirstURL(music, @[ @"playUrl", @"playUrlHq", @"urlList", @"url" ]);
        if (u.length) info.musicURL = [self cleanDownloadURL:u preferHD:NO];
    }

    // ---- 封面 ----
    id cover = APXGet(videoContainer, @"cover") ?: APXGet(videoContainer, @"originCover");
    if (cover) {
        NSString *u = APXFirstURL(cover, @[ @"urlList", @"url" ]);
        if (u.length) info.coverURL = u;
    }

    APXLog(@"提取结果：%@", [info summary]);
    return info;
}

@end
