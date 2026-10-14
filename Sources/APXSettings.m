//
//  APXSettings.m
//  AwemePlus
//
//  纯本地设置页：只有 NSUserDefaults 读写，没有任何网络、授权、校验逻辑。
//

#import "APXSettings.h"
#import "APXCommon.h"
#import "APXPreferences.h"

#pragma mark - 开关行

@interface APXSwitchRow : UIView

@property (nonatomic, copy) NSString *key;
@property (nonatomic, strong) UISwitch *toggle;

- (instancetype)initWithTitle:(NSString *)title subtitle:(NSString *)subtitle key:(NSString *)key;
- (void)refresh;
- (void)toggleChanged;

@end

@implementation APXSwitchRow

- (instancetype)initWithTitle:(NSString *)title subtitle:(NSString *)subtitle key:(NSString *)key {
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;

    _key = [key copy];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.font = [UIFont systemFontOfSize:15.0];
    titleLabel.textColor = UIColor.labelColor;
    titleLabel.numberOfLines = 0;

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.text = subtitle;
    subtitleLabel.font = [UIFont systemFontOfSize:11.5];
    subtitleLabel.textColor = UIColor.secondaryLabelColor;
    subtitleLabel.numberOfLines = 0;

    UIStackView *textStack = [[UIStackView alloc] initWithArrangedSubviews:@[ titleLabel, subtitleLabel ]];
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.spacing = 1.0;

    _toggle = [[UISwitch alloc] init];
    [_toggle addTarget:self action:@selector(toggleChanged) forControlEvents:UIControlEventValueChanged];
    // 用 751 而不是 Required：多行标题在窄屏上需要能压缩，Required 会触发约束冲突
    [_toggle setContentHuggingPriority:751 forAxis:UILayoutConstraintAxisHorizontal];
    [_toggle setContentCompressionResistancePriority:UILayoutPriorityRequired
                                             forAxis:UILayoutConstraintAxisHorizontal];

    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[ textStack, _toggle ]];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentCenter;
    row.spacing = 12.0;
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:row];

    [NSLayoutConstraint activateConstraints:@[
        [row.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16.0],
        [row.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16.0],
        [row.topAnchor constraintEqualToAnchor:self.topAnchor constant:10.0],
        [row.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-10.0],
        [self.heightAnchor constraintGreaterThanOrEqualToConstant:56.0],
    ]];

    [self refresh];
    return self;
}

- (void)refresh {
    self.toggle.on = [APXPreferences boolForKey:self.key defaultValue:YES];
}

- (void)toggleChanged {
    [APXPreferences setBool:self.toggle.isOn forKey:self.key];
    APXLog(@"设置项 %@ = %@", self.key, self.toggle.isOn ? @"ON" : @"OFF");
}

@end

#pragma mark - 设置页

@interface APXSettingsViewController ()
- (void)close;
@end

@implementation APXSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"AwemePlus";
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.navigationItem.rightBarButtonItem =
    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                  target:self
                                                  action:@selector(close)];

    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.alwaysBounceVertical = YES;
    [self.view addSubview:scroll];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 0.0;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [stack.topAnchor constraintEqualToAnchor:scroll.topAnchor constant:12.0],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.bottomAnchor constant:-24.0],
        [stack.widthAnchor constraintEqualToAnchor:scroll.widthAnchor],
    ]];

    UIView *card = [[UIView alloc] init];
    card.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    card.layer.cornerRadius = 12.0;
    card.layer.masksToBounds = YES;

    UIStackView *cardStack = [[UIStackView alloc] init];
    cardStack.axis = UILayoutConstraintAxisVertical;
    cardStack.spacing = 0.0;
    cardStack.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:cardStack];
    [NSLayoutConstraint activateConstraints:@[
        [cardStack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [cardStack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
        [cardStack.topAnchor constraintEqualToAnchor:card.topAnchor],
        [cardStack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor],
    ]];

    NSArray<NSArray<NSString *> *> *items = [APXPreferences settingItems];
    [items enumerateObjectsUsingBlock:^(NSArray<NSString *> *item, NSUInteger idx, BOOL *stop) {
        APXSwitchRow *row = [[APXSwitchRow alloc] initWithTitle:item[1] subtitle:item[2] key:item[0]];
        [cardStack addArrangedSubview:row];
        if (idx + 1 < items.count) {
            UIView *line = [[UIView alloc] init];
            line.backgroundColor = UIColor.separatorColor;
            [line.heightAnchor constraintEqualToConstant:0.5].active = YES;
            UIStackView *wrap = [[UIStackView alloc] initWithArrangedSubviews:@[ line ]];
            wrap.layoutMargins = UIEdgeInsetsMake(0, 16, 0, 0);
            wrap.layoutMarginsRelativeArrangement = YES;
            [cardStack addArrangedSubview:wrap];
        }
    }];

    UIStackView *cardWrap = [[UIStackView alloc] initWithArrangedSubviews:@[ card ]];
    cardWrap.layoutMargins = UIEdgeInsetsMake(0, 16, 0, 16);
    cardWrap.layoutMarginsRelativeArrangement = YES;
    [stack addArrangedSubview:cardWrap];

    UILabel *footer = [[UILabel alloc] init];
    footer.numberOfLines = 0;
    footer.textAlignment = NSTextAlignmentCenter;
    footer.font = [UIFont systemFontOfSize:11.5];
    footer.textColor = UIColor.secondaryLabelColor;
    footer.text = @"本插件完全离线运行：\n不连接任何自建服务器，无授权校验、无卡密、\n不采集设备信息、不上报任何数据。\n\n唯一的外部请求是你主动触发的视频/图片下载，\n目标地址由抖音客户端自己返回。";
    UIStackView *footerWrap = [[UIStackView alloc] initWithArrangedSubviews:@[ footer ]];
    footerWrap.layoutMargins = UIEdgeInsetsMake(18, 24, 0, 24);
    footerWrap.layoutMarginsRelativeArrangement = YES;
    [stack addArrangedSubview:footerWrap];
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
