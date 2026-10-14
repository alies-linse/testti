//
//  APXCommon.m
//  AwemePlus
//

#import "APXCommon.h"
#import "APXPreferences.h"
#import <os/lock.h>

#pragma mark - 日志

BOOL APXLogEnabled(void) {
    // 每次实时读取，这样在设置里开关「详细日志」立即生效。
    return [APXPreferences verboseLogging];
}

#pragma mark - Runtime

/// IMP 表要跨线程访问：安装在主线程，读取发生在任意线程的 hook 调用里。
/// 没锁的话，一次并发读可能拿到 NULL，hook 就会「跳过原实现」——那会直接把宿主 App 弄坏。
static os_unfair_lock gAPXIMPLock = OS_UNFAIR_LOCK_INIT;

static NSMutableDictionary<NSString *, NSValue *> *APXOrigIMPTable(void) {
    static NSMutableDictionary *table;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        table = [NSMutableDictionary dictionary];
    });
    return table;
}

/// key 里必须带 I/M 标记：类与它的元类 class_getName 同名，
/// 否则 -foo 和 +foo 会撞到同一条记录，取回错误的 IMP（参数个数都不对）。
static NSString *APXIMPKey(Class cls, SEL sel, BOOL isClassMethod) {
    return [NSString stringWithFormat:@"%c|%s|%s",
            isClassMethod ? 'M' : 'I', class_getName(cls), sel_getName(sel)];
}

static void APXIMPTableStore(Class owner, SEL sel, BOOL isClassMethod, IMP imp) {
    NSString *key = APXIMPKey(owner, sel, isClassMethod);
    os_unfair_lock_lock(&gAPXIMPLock);
    APXOrigIMPTable()[key] = [NSValue valueWithPointer:imp];
    os_unfair_lock_unlock(&gAPXIMPLock);
}

/// 找出「真正定义了这个方法」的类。
///
/// class_getInstanceMethod 会沿继承链查找，而 method_setImplementation 改的是
/// 定义该方法的那个类。如果按调用方传来的类去记账，遇到「子类继承父类方法」的情况
/// 就会把 key 记在子类头上：运行时 APXOriginalIMP 从实例的类往上找，找不到这条记录，
/// 于是原实现永远不会被调用 —— 那是会把宿主 App 直接搞坏的。
static Class APXOwningClass(Class cls, SEL sel, Method m, BOOL isClassMethod) {
    Class owner = cls;
    Class super = class_getSuperclass(owner);
    while (super) {
        Method sm = isClassMethod ? class_getClassMethod(super, sel)
                                  : class_getInstanceMethod(super, sel);
        if (sm != m) break;          // 到了这一层方法已经不是同一个了，说明 owner 就是定义处
        owner = super;
        super = class_getSuperclass(owner);
    }
    return owner;
}

IMP APXSwizzleInstance(Class cls, SEL sel, IMP replacement) {
    if (!cls || !sel || !replacement) return NULL;
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return NULL;
    IMP old = method_getImplementation(m);
    if (old == replacement) return old;   // 之前已经挂过（含子类先挂、父类后挂的情况）
    APXIMPTableStore(APXOwningClass(cls, sel, m, NO), sel, NO, old);
    method_setImplementation(m, replacement);
    return old;
}

IMP APXSwizzleClass(Class cls, SEL sel, IMP replacement) {
    if (!cls || !sel || !replacement) return NULL;
    Method m = class_getClassMethod(cls, sel);
    if (!m) return NULL;
    IMP old = method_getImplementation(m);
    if (old == replacement) return old;
    APXIMPTableStore(APXOwningClass(cls, sel, m, YES), sel, YES, old);
    method_setImplementation(m, replacement);
    return old;
}

IMP APXOriginalIMP(id receiver, SEL sel) {
    if (!receiver || !sel) return NULL;
    Class start = object_getClass(receiver);
    // 类方法时 object_getClass 返回元类，元类的 class_getName 与类同名，
    // 所以从元类往上走一样能命中 'M' 记录；先按实例方法（'I'）找。
    os_unfair_lock_lock(&gAPXIMPLock);
    NSDictionary *table = APXOrigIMPTable();
    IMP found = NULL;
    for (Class c = start; c && !found; c = class_getSuperclass(c)) {
        NSValue *v = table[APXIMPKey(c, sel, NO)];
        if (v) { found = (IMP)v.pointerValue; break; }
        v = table[APXIMPKey(c, sel, YES)];
        if (v) { found = (IMP)v.pointerValue; break; }
    }
    os_unfair_lock_unlock(&gAPXIMPLock);
    return found;
}

NSArray<Class> *APXClassesRespondingToSelector(SEL sel) {
    NSMutableArray<Class> *result = [NSMutableArray array];
    if (!sel) return result;
    unsigned int count = 0;
    Class *classes = objc_copyClassList(&count);
    if (!classes) return result;
    for (unsigned int i = 0; i < count; i++) {
        Class c = classes[i];
        if (c && class_respondsToSelector(c, sel)) {
            [result addObject:c];
        }
    }
    free(classes);
    return result;
}

NSArray<Class> *APXClassesWithNameContaining(NSString *needle) {
    NSMutableArray<Class> *result = [NSMutableArray array];
    if (!needle.length) return result;
    unsigned int count = 0;
    Class *classes = objc_copyClassList(&count);
    if (!classes) return result;
    for (unsigned int i = 0; i < count; i++) {
        Class c = classes[i];
        const char *name = c ? class_getName(c) : NULL;
        if (!name) continue;
        NSString *n = @(name);
        if ([n containsString:needle]) [result addObject:c];
    }
    free(classes);
    return result;
}

#pragma mark - 安全取值

id APXGet(id obj, NSString *key) {
    if (!obj || !key.length) return nil;
    @try {
        return [obj valueForKey:key];
    } @catch (__unused NSException *e) {
        return nil;
    }
}

BOOL APXSet(id obj, NSString *key, id value) {
    if (!obj || !key.length) return NO;
    @try {
        [obj setValue:value forKey:key];
        return YES;
    } @catch (__unused NSException *e) {
        return NO;
    }
}

NSString *APXClassName(id obj) {
    if (!obj) return @"";
    return NSStringFromClass(object_getClass(obj)) ?: @"";
}

BOOL APXIsKindOfNamedClass(id obj, NSArray<NSString *> *classPrefixes) {
    if (!obj) return NO;
    NSString *name = APXClassName(obj);
    if (!name.length) return NO;
    for (NSString *prefix in classPrefixes) {
        if (prefix.length && [name hasPrefix:prefix]) return YES;
    }
    return NO;
}

#pragma mark - ivar 树查找

/// 这些类型的对象没必要继续往里钻，避免无谓开销与死循环风险。
static BOOL APXIsLeafObject(id v) {
    return [v isKindOfClass:[NSString class]]
        || [v isKindOfClass:[NSNumber class]]
        || [v isKindOfClass:[NSData class]]
        || [v isKindOfClass:[NSDate class]]
        || [v isKindOfClass:[NSURL class]]
        || [v isKindOfClass:[NSNull class]]
        || [v isKindOfClass:[NSValue class]]
        || [v isKindOfClass:[NSError class]];
}

/// 取某个类（含父类链）的所有对象型 ivar 的值。
static void APXCollectIvarObjects(id obj, void (^block)(id value, BOOL *stop)) {
    if (!obj) return;
    BOOL stop = NO;
    for (Class c = object_getClass(obj); c && c != [NSObject class] && !stop; c = class_getSuperclass(c)) {
        unsigned int n = 0;
        Ivar *ivars = class_copyIvarList(c, &n);
        if (!ivars) continue;
        for (unsigned int i = 0; i < n && !stop; i++) {
            const char *type = ivar_getTypeEncoding(ivars[i]);
            if (!type || type[0] != '@') continue;   // 只处理对象类型
            id value = nil;
            @try {
                value = object_getIvar(obj, ivars[i]);
            } @catch (__unused NSException *e) {
                value = nil;
            }
            if (value) block(value, &stop);
        }
        free(ivars);
    }
}

id APXFindIvar(id obj, NSArray<NSString *> *classPrefixes, NSUInteger maxDepth) {
    if (!obj || !classPrefixes.count || maxDepth == 0) return nil;

    __block id found = nil;

    // 第 1 层：直接 ivar，以及数组元素
    APXCollectIvarObjects(obj, ^(id value, BOOL *stop) {
        if (APXIsKindOfNamedClass(value, classPrefixes)) {
            found = value; *stop = YES; return;
        }
        if ([value isKindOfClass:[NSArray class]]) {
            NSArray *arr = (NSArray *)value;
            if (arr.count <= 200) {                 // 大数组不扫，避免卡顿
                for (id element in arr) {
                    if (APXIsKindOfNamedClass(element, classPrefixes)) {
                        found = element; *stop = YES; return;
                    }
                }
            }
        }
    });
    if (found) return found;
    if (maxDepth <= 1) return nil;

    // 第 2 层：递归进容器对象
    APXCollectIvarObjects(obj, ^(id value, BOOL *stop) {
        if (APXIsLeafObject(value)) return;
        if ([value isKindOfClass:[NSArray class]]) {
            NSArray *arr = (NSArray *)value;
            if (arr.count > 200) return;
            for (id element in arr) {
                if (APXIsLeafObject(element)) continue;
                id r = APXFindIvar(element, classPrefixes, 1);
                if (r) { found = r; *stop = YES; return; }
            }
            return;
        }
        if ([value isKindOfClass:[NSDictionary class]] || [value isKindOfClass:[NSSet class]]) return;
        id r = APXFindIvar(value, classPrefixes, maxDepth - 1);
        if (r) { found = r; *stop = YES; }
    });

    return found;
}

#pragma mark - UI

UIWindow *APXKeyWindow(void) {
    UIApplication *app = UIApplication.sharedApplication;
    if (!app) return nil;
    for (UIWindow *w in app.windows) {
        if (w.isKeyWindow) return w;
    }
    return app.windows.firstObject;
}

UIViewController *APXTopViewController(void) {
    UIViewController *vc = APXKeyWindow().rootViewController;
    // 逐层往下找最前面的控制器，最多 12 层，防止异常嵌套导致死循环
    for (NSUInteger i = 0; i < 12 && vc; i++) {
        UIViewController *next = nil;
        if (vc.presentedViewController) {
            next = vc.presentedViewController;
        } else if ([vc isKindOfClass:[UINavigationController class]]) {
            next = ((UINavigationController *)vc).visibleViewController;
        } else if ([vc isKindOfClass:[UITabBarController class]]) {
            next = ((UITabBarController *)vc).selectedViewController;
        }
        if (!next || next == vc) break;
        vc = next;
    }
    return vc;
}
