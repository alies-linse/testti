//
//  APXMenu.m
//  AwemePlus
//

#import "APXMenu.h"
#import "APXCommon.h"
#import "APXPreferences.h"
#import "APXModelCenter.h"
#import "APXExtractor.h"
#import "APXDownloader.h"
#import "APXHUD.h"
#import "APXSettings.h"

static const void *kAPXGestureKey = "apx_gesture_installed";

#pragma mark - 通用行视图

@interface APXRowView : UIControl

@property (nonatomic, copy) void (^action)(void);

- (instancetype)initWithTitle:(NSString *)title subtitle:(NSString *)subtitle;
- (void)setRowEnabled:(BOOL)enabled;
- (void)handleTap;

@end

@implementation APXRowView {
    UILabel *_titleLabel;
    UILabel *_subtitleLabel;
    UIImageView *_chevron;
}

- (instancetype)initWithTitle:(NSString *)title subtitle:(NSString *)subtitle {
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.text = title;
    _titleLabel.font = [UIFont systemFontOfSize:15.5 weight:UIFontWeightSemibold];
    _titleLabel.textColor = UIColor.whiteColor;
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    _subtitleLabel = [[UILabel alloc] init];
    _subtitleLabel.text = subtitle;
    _subtitleLabel.font = [UIFont systemFontOfSize:12.0];
    _subtitleLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.55];
    _subtitleLabel.numberOfLines = 2;
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    _chevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"]];
    _chevron.tintColor = [UIColor colorWithWhite:1.0 alpha:0.3];
    _chevron.translatesAutoresizingMaskIntoConstraints = NO;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[ _titleLabel, _subtitleLabel ]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 2.0;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.userInteractionEnabled = NO;
    [self addSubview:stack];
    [self addSubview:_chevron];

    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16.0],
        [stack.topAnchor constraintEqualToAnchor:self.topAnchor constant:11.0],
        [stack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-11.0],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:_chevron.leadingAnchor constant:-10.0],
        [_chevron.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-14.0],
        [_chevron.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
    ]];

    [self addTarget:self action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
    return self;
}

- (void)setRowEnabled:(BOOL)enabled {
    self.enabled = enabled;
    self.alpha = enabled ? 1.0 : 0.38;
}

- (void)handleTap {
    [UIView animateWithDuration:0.08 animations:^{
        self.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.10];
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.16 animations:^{
            self.backgroundColor = UIColor.clearColor;
        }];
    }];
    if (self.action) self.action();
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.backgroundColor = highlighted ? [UIColor colorWithWhite:1.0 alpha:0.10] : UIColor.clearColor;
}

@end

#pragma mark - 菜单控制器

@interface APXMenuViewController : UIViewController <UIGestureRecognizerDelegate>
- (instancetype)initWithInfo:(nullable APXAwemeInfo *)info;
- (void)buildContent;
- (UIView *)separator;
- (void)runDownload:(APXDownloadMode)mode;
- (void)backgroundTapped;
@end

@implementation APXMenuViewController {
    APXAwemeInfo *_info;
    UIView *_card;
}

- (instancetype)initWithInfo:(APXAwemeInfo *)info {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _info = info;
        self.modalPresentationStyle = UIModalPresentationOverFullScreen;
        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.45];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backgroundTapped)];
    tap.delegate = self;
    [self.view addGestureRecognizer:tap];

    _card = [[UIView alloc] init];
    _card.backgroundColor = [UIColor colorWithWhite:0.11 alpha:1.0];
    _card.layer.cornerRadius = 18.0;
    _card.layer.masksToBounds = YES;
    _card.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_card];

    [NSLayoutConstraint activateConstraints:@[
        [_card.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_card.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [_card.widthAnchor constraintEqualToAnchor:self.view.widthAnchor multiplier:0.86],
    ]];

    [self buildContent];
}

- (void)buildContent {
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 0.0;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [_card addSubview:stack];

    // 标题区
    UILabel *title = [[UILabel alloc] init];
    title.text = @"AwemePlus";
    title.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightBold];
    title.textColor = UIColor.whiteColor;

    UILabel *subtitle = [[UILabel alloc] init];
    subtitle.text = _info ? [_info summary] : @"未识别到当前作品";
    subtitle.font = [UIFont systemFontOfSize:11.5];
    subtitle.textColor = [UIColor colorWithWhite:1.0 alpha:0.5];
    subtitle.numberOfLines = 3;

    UIStackView *header = [[UIStackView alloc] initWithArrangedSubviews:@[ title, subtitle ]];
    header.axis = UILayoutConstraintAxisVertical;
    header.spacing = 3.0;
    header.layoutMargins = UIEdgeInsetsMake(16, 16, 12, 16);
    header.layoutMarginsRelativeArrangement = YES;
    [stack addArrangedSubview:header];
    [stack addArrangedSubview:[self separator]];

    __weak typeof(self) weakSelf = self;

    // 视频
    APXRowView *videoRow = [[APXRowView alloc] initWithTitle:@"下载视频（无水印）"
                                                    subtitle:_info.hasVideo ? [NSString stringWithFormat:@"%lu 个候选地址，自动重试", (unsigned long)_info.videoURLs.count]
                                                                           : @"未找到视频地址"];
    [videoRow setRowEnabled:_info.hasVideo];
    videoRow.action = ^{ [weakSelf runDownload:APXDownloadModeVideo]; };
    [stack addArrangedSubview:videoRow];
    [stack addArrangedSubview:[self separator]];

    // 图集
    APXRowView *imageRow = [[APXRowView alloc] initWithTitle:@"下载图集"
                                                    subtitle:_info.hasImages ? [NSString stringWithFormat:@"共 %lu 张", (unsigned long)_info.imageURLs.count]
                                                                             : @"当前作品不是图集"];
    [imageRow setRowEnabled:_info.hasImages];
    imageRow.action = ^{ [weakSelf runDownload:APXDownloadModeImages]; };
    [stack addArrangedSubview:imageRow];
    [stack addArrangedSubview:[self separator]];

    // 音频
    APXRowView *musicRow = [[APXRowView alloc] initWithTitle:@"保存背景音乐"
                                                    subtitle:_info.musicURL.length ? @"保存为该作品的音频" : @"没有可下载的音频"];
    [musicRow setRowEnabled:_info.musicURL.length > 0];
    musicRow.action = ^{ [weakSelf runDownload:APXDownloadModeMusic]; };
    [stack addArrangedSubview:musicRow];
    [stack addArrangedSubview:[self separator]];

    // 复制文案
    NSString *descText = _info.desc;
    APXRowView *copyDesc = [[APXRowView alloc] initWithTitle:@"复制文案"
                                                    subtitle:descText.length ? descText : @"没有文案"];
    [copyDesc setRowEnabled:descText.length > 0];
    copyDesc.action = ^{
        UIPasteboard.generalPasteboard.string = descText ?: @"";
        [APXHUD toast:@"文案已复制"];
        [weakSelf dismissViewControllerAnimated:YES completion:nil];
    };
    [stack addArrangedSubview:copyDesc];
    [stack addArrangedSubview:[self separator]];

    // 复制直链
    NSString *directURL = _info.videoURLs.firstObject;
    APXRowView *copyURL = [[APXRowView alloc] initWithTitle:@"复制视频直链"
                                                   subtitle:directURL.length ? @"可直接粘贴到下载工具" : @"没有可用地址"];
    [copyURL setRowEnabled:directURL.length > 0];
    copyURL.action = ^{
        UIPasteboard.generalPasteboard.string = directURL ?: @"";
        [APXHUD toast:@"直链已复制"];
        [weakSelf dismissViewControllerAnimated:YES completion:nil];
    };
    [stack addArrangedSubview:copyURL];
    [stack addArrangedSubview:[self separator]];

    // 设置
    APXRowView *settings = [[APXRowView alloc] initWithTitle:@"设置" subtitle:@"全部本地开关，无联网校验"];
    settings.action = ^{
        APXSettingsViewController *vc = [[APXSettingsViewController alloc] init];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
        [weakSelf presentViewController:nav animated:YES completion:nil];
    };
    [stack addArrangedSubview:settings];
    [stack addArrangedSubview:[self separator]];

    // 说明
    UILabel *footer = [[UILabel alloc] init];
    footer.text = @"无服务器 · 无授权校验 · 无设备指纹\n所有处理都在本机完成";
    footer.numberOfLines = 2;
    footer.textAlignment = NSTextAlignmentCenter;
    footer.font = [UIFont systemFontOfSize:10.5];
    footer.textColor = [UIColor colorWithWhite:1.0 alpha:0.35];
    UIStackView *footerWrap = [[UIStackView alloc] initWithArrangedSubviews:@[ footer ]];
    footerWrap.layoutMargins = UIEdgeInsetsMake(12, 16, 14, 16);
    footerWrap.layoutMarginsRelativeArrangement = YES;
    [stack addArrangedSubview:footerWrap];

    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:_card.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:_card.bottomAnchor],
    ]];
}

- (UIView *)separator {
    UIView *line = [[UIView alloc] init];
    line.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
    [line.heightAnchor constraintEqualToConstant:0.5].active = YES;
    return line;
}

- (void)runDownload:(APXDownloadMode)mode {
    APXAwemeInfo *info = _info;
    if (!info) { [APXHUD toast:@"没有作品信息"]; return; }
    [self dismissViewControllerAnimated:YES completion:^{
        [APXDownloader downloadInfo:info mode:mode];
    }];
}

- (void)backgroundTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - 让卡片内部的点击不触发「点背景关闭」

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if (!_card) return YES;
    return ![touch.view isDescendantOfView:_card];
}

@end

#pragma mark - 手势与入口

@interface APXMenuPresenter ()
- (void)handleGesture:(UITapGestureRecognizer *)gesture;
@end

@implementation APXMenuPresenter

+ (instancetype)shared {
    static APXMenuPresenter *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[APXMenuPresenter alloc] init]; });
    return shared;
}

- (void)installGesture {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (![APXPreferences enabled] || ![APXPreferences gestureMenuEnabled]) return;
        UIWindow *window = APXKeyWindow();
        if (!window) return;
        if (objc_getAssociatedObject(window, kAPXGestureKey)) return;

        UITapGestureRecognizer *gesture =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleGesture:)];
        gesture.numberOfTapsRequired = 2;
        gesture.numberOfTouchesRequired = 2;
        gesture.cancelsTouchesInView = NO;
        gesture.delegate = self;
        [window addGestureRecognizer:gesture];
        objc_setAssociatedObject(window, kAPXGestureKey, gesture, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        APXLog(@"已安装双指双击手势（window=%@）", APXClassName(window));
    });
}

- (void)handleGesture:(UITapGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateEnded) return;
    if (![APXPreferences enabled]) return;
    UIViewController *top = APXTopViewController();
    if ([top isKindOfClass:[APXMenuViewController class]]) return;   // 菜单已开着
    [self presentMenu];
}

- (void)presentMenu {
    if (![APXPreferences enabled]) return;
    UIViewController *top = APXTopViewController();
    if (!top) { [APXHUD toast:@"界面还没准备好"]; return; }

    id model = [APXModelCenter currentModel];
    APXAwemeInfo *info = model ? [APXExtractor infoFromModel:model] : nil;

    APXMenuViewController *menu = [[APXMenuViewController alloc] initWithInfo:info];
    [top presentViewController:menu animated:YES completion:nil];
}

#pragma mark - 手势代理

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;   // 不干扰抖音自己的手势
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return NO;
}

@end
