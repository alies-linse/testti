//
//  APXExtractor.h
//  AwemePlus
//
//  从抖音的作品模型里，把「能直接下载的地址」抠出来。
//  抖音的模型字段历代变化很大，所以这里全部用 KVC 试探 + 多候选键，
//  任何一环拿不到都不会崩，只是少一个候选源。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface APXAwemeInfo : NSObject

@property (nonatomic, copy,   nullable) NSString *awemeID;
@property (nonatomic, copy,   nullable) NSString *desc;
@property (nonatomic, copy,   nullable) NSArray<NSString *> *videoURLs;   // 已按「优先无水印」排序
@property (nonatomic, copy,   nullable) NSArray<NSString *> *imageURLs;   // 图集
@property (nonatomic, copy,   nullable) NSString *musicURL;               // 背景音乐
@property (nonatomic, copy,   nullable) NSString *coverURL;               // 封面
@property (nonatomic, copy,   nullable) NSString *sourceClassName;
@property (nonatomic, assign) BOOL isAlbum;

- (BOOL)hasVideo;
- (BOOL)hasImages;
- (NSString *)summary;   // 给日志/提示用的一句话

@end

@interface APXExtractor : NSObject

/// 传入作品模型（AWEAwemeModel 之类）或视频模型（AWEVideoModel 之类）都可以
+ (nullable APXAwemeInfo *)infoFromModel:(id)model;

/// 下载地址清洗：去水印参数、playwm→play、可选提升码率
+ (NSString *)cleanDownloadURL:(NSString *)url preferHD:(BOOL)preferHD;

@end

NS_ASSUME_NONNULL_END
