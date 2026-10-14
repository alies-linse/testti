# AwemePlus —— 抖音增强 tweak（纯净版）
#
# 设计原则：无服务器 / 无授权校验 / 无设备指纹 / 无遥测。
# 全部逻辑在本机完成，唯一的网络请求是下载视频本身（抖音自己的 CDN）。
#
# 常用命令：
#   make package           构建 deb
#   make clean             清理
#   THEOS_DEVICE_IP=... make install   装到设备

ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless

INSTALL_TARGET_PROCESSES = Aweme

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AwemePlus
AwemePlus_FILES = Tweak.m $(wildcard Sources/*.m)
AwemePlus_CFLAGS = -fobjc-arc -ISources -Wno-deprecated-declarations -Wno-unused-function
# AVFoundation / CoreMedia / CoreGraphics 目前没用到，是给 v0.2 的实况照片合成预留的；
# Foundation / CoreFoundation / libobjc 由 Theos 自动加上，不用写。
AwemePlus_FRAMEWORKS = Foundation UIKit Photos AVFoundation CoreMedia CoreGraphics
AwemePlus_LDFLAGS = -Wl,-undefined,dynamic_lookup

include $(THEOS_MAKE_PATH)/tweak.mk

# 这两个文件放在项目根目录是 Theos 的硬要求：
# makefiles/instance/tweak.mk 会去找 <TWEAK_NAME>.plist 或 Filter.plist 并复制到
# $(LOCAL_INSTALL_PATH)（默认 /Library/MobileSubstrate/DynamicLibraries），
# 两个都没有就直接报 "You are missing a filter property list"。
# 放在 layout/ 里也行但没必要，两边都放会产生重复文件。

# 本项目只用 ObjC runtime 做方法替换，不需要 CydiaSubstrate / ElleKit 的 API。
# （实测当前 Theos 并不会默认追加 substrate 链接，下面这行是给未来/魔改版留的保险，
#   放在 include 之后是有意的：_LIBRARIES 是递归展开的，链接期才会读到最终值。）
AwemePlus_LIBRARIES := $(filter-out substrate,$(AwemePlus_LIBRARIES))

after-install::
	install.exec "killall -9 Aweme 2>/dev/null || true"
