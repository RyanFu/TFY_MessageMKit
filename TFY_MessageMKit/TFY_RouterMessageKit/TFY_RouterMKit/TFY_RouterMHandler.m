//
//  TFY_RouterMHandler.m
//  TFY_MessageMKit
//
//  Created by 田风有 on 2020/8/23.
//

#import "TFY_RouterMHandler.h"
#import "TFY_RouterM.h"
#import <objc/runtime.h>

#pragma mark - Define&StaticVar -- 静态变量和Define声明
/** Debug模式打印Log信息 */
#ifdef DEBUG
#define RouterMHandlerLog(...) !TFY_RouterM.debug ? : NSLog(@"\n%s 第%d行: \n %@\n\n",__func__,__LINE__,[NSString stringWithFormat:__VA_ARGS__])
#else
#define RouterMHandlerLog(...)
#endif

/** 简称*方法Key */
NSString * const RouterMHandlerStarHostActionKey = @"com.tfy.RouterMHandlerStarHostActionKey";
/** 类称*方法Key */
NSString * const RouterMHandlerStarClassActionKey = @"com.tfy.RouterMHandlerStarClassActionKey";
/** 重定向记录 */
static NSMutableArray *RouterMHandlerRedirectLogs;


@interface TFY_RouterMHandler (){
@private
    /** 路由类映射 */
    NSMutableDictionary *RouterMQuickLookClass;
@private
    /** 路由方法映射 */
    NSMutableDictionary *RouterMQuickLookAction;
@private
    /** 存储容错的方法 */
    NSDictionary *RouterMErrorAction;
}

/** 协议 */
@property(nonatomic, strong)NSString *scheme;
/** 类前缀 */
@property(nonatomic, strong)NSString *classPrefix;
/** 方法前缀 */
@property(nonatomic, strong)NSString *actionPrefix;
/** 是否忽略大小写 */
@property(nonatomic, assign)BOOL ignoredCase;

@end

@implementation TFY_RouterMHandler

+ (void)initialize {
    RouterMHandlerRedirectLogs = RouterMHandlerRedirectLogs ? : [NSMutableArray array];
}

#pragma mark - Life Circle -- 生命周期和初始化设置

/**
 初始化
 */
- (instancetype)init {
    self = [super init];
    if (self) {
        RouterMQuickLookClass = [NSMutableDictionary dictionary];
        RouterMQuickLookAction = [NSMutableDictionary dictionary];
    }
    return self;
}


/**
 快速生成handler
 
  scheme 协议
  classPrefix 类前缀
  actionPreFix 方法前缀
 @return handler
 */
+ (instancetype)tfy_handlerWithScheme:(NSString *)scheme
                      classPrefix:(NSString *)classPrefix
                     actionPreFix:(NSString *)actionPreFix
                      ignoredCase:(BOOL)ignored {
    
    TFY_RouterMHandler *handler = [self new];
    handler.scheme = scheme;
    handler.classPrefix = classPrefix;
    handler.actionPrefix = actionPreFix;
    handler.ignoredCase = ignored;
    return handler;
}

#pragma mark - Private -- 私有方法

/**
 判断是否可以正确执行方法
 
  classNamePoint 类名
  actionNamePoint 方法名
  error 错误信息
 */
- (BOOL)tfy_canPerFormClass:(inout NSString **)classNamePoint
                 action:(inout NSString **)actionNamePoint
                  error:(inout NSError **)error
                 target:(inout id *)targetPoint
                   star:(NSMutableDictionary *)starSelectors {
    
    NSString *routerHost = * classNamePoint;
    NSString *routerPath = * actionNamePoint;
    
    NSString *className;
    NSString *actionName;
    /** 获取类名和方法名 */
    [self tfy_getClassNameAndActionNameFormHost:routerHost
                                toClassName:&className
                                       path:routerPath
                               toActionName:&actionName
                                      error:error];
    
    /** 获取类名称 */
    NSString *classString = [self tfy_getClassString:className];
    
    /** 获取selecter名称 */
    NSString *actionString;
    if ([self.actionPrefix length]) {
        actionString = [NSString stringWithFormat:@"%@%@:", self.actionPrefix, actionName];
    }else{
        actionString = [NSString stringWithFormat:@"%@:", actionName];
    }
    
    *classNamePoint = classString;
    *actionNamePoint = actionString;
    RouterMHandlerLog(@"[%@]映射后的类名为[%@]", routerHost, classString);
    RouterMHandlerLog(@"[%@]映射后的方法名为[%@]", routerPath, actionString);
    
    //获取类
    Class targetClass = NSClassFromString(classString);
    //获取类的实例对象
    id target = [[targetClass alloc] init];
    if (!target) {
        if (error) {
            *error = [NSError errorWithDomain:[NSString stringWithFormat:@"[%@]映射后的类名[%@]不正确", routerHost, classString]
                                         code:TFY_RouterMStatusNotFoundClass
                                     userInfo:nil];
        }
        return NO;
    }
    if (targetPoint) {
        *targetPoint = target;
    }
    //获取类的实例方法
    SEL action = NSSelectorFromString(actionString);
    //判定实例对象是否有对应方法
    if (![target respondsToSelector:action]) {
        /**
         这里实现*方法
         在存在target的情况下，若该类注册了*方法，则可以跳转到*方法中
         */
        [self tfy_handlerStarMethodHost:routerHost className:className actionName:actionName selectorsContain:starSelectors error:error];
        
        if (error && starSelectors.count <= 0) {
            *error = [NSError errorWithDomain:[NSString stringWithFormat:@"[%@]映射后的方法名[%@]不正确", routerPath, actionString]
                                         code:TFY_RouterMStatusNotFoundAction
                                     userInfo:nil];
        }
        return NO;
    }
    return YES;
}

- (NSString *)tfy_ignoredCaseString:(NSString *)string {
    if (self.ignoredCase) {
        return [string lowercaseString];
    }
    return string;
}

/**
 获取类名和方法名
 
  routerHost 路由host映射类
  toClassNamePoint 输出类名
  routerPath 路由path映射方法
  toActionNamePoint 输出方法名
  error  错误信息
 */
- (void)tfy_getClassNameAndActionNameFormHost:(NSString *)routerHost toClassName:(inout NSString **)toClassNamePoint
                                     path:(NSString *)routerPath toActionName:(inout NSString **)toActionNamePoint
                                    error:(inout NSError **)error{
    NSString *className;
    NSString *actionName;
    routerHost = [self tfy_ignoredCaseString:routerHost];
    routerPath = [self tfy_ignoredCaseString:routerPath];
    
    /** 简称拼接[/host/path] */
    NSString *hostPathClassActionName = [@"/" stringByAppendingPathComponent:[NSString stringWithFormat:@"%@%@", routerHost, routerPath]];
    
    if ([RouterMQuickLookClass.allKeys containsObject: routerHost]) {
        className = RouterMQuickLookClass[routerHost];
        
        /** 只有有类才会走类称拼接 */
        /** 类称拼接[/类名/path] */
        NSString *classActionName = [self tfy_ignoredCaseString:[@"/" stringByAppendingPathComponent:[NSString stringWithFormat:@"%@%@", className, routerPath]]];
        /** 如果注册了类称拼接 */
        if ([RouterMQuickLookAction.allKeys containsObject: classActionName]) {
            actionName = RouterMQuickLookAction[classActionName];
        }
    } else {
        /** 若没有映射，类型可能会有[.]，置换出_ */
        className = [routerHost stringByReplacingOccurrencesOfString:@"." withString:@"_"];
    }
    /** 如果为空则未走类称拼接 */
    if (!actionName) {
        if ([RouterMQuickLookAction.allKeys containsObject: hostPathClassActionName]) {
            /** 如果注册了简称拼接 */
            actionName = RouterMQuickLookAction[hostPathClassActionName];
        } else {
            /** 如果注册了简称方法 */
            if ([RouterMQuickLookAction.allKeys containsObject: routerPath]) {
                actionName = RouterMQuickLookAction[routerPath];
            } else {
                actionName = [routerPath stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
            }
        }
    }
    
    /** 获取类名称 */
    NSString *classString = [self tfy_getClassString:className];
    /** 获取的类名不存在 且存在容错方法直接获取容错方法 */
    if ((NSClassFromString(classString)) == nil && RouterMErrorAction.allKeys.count == 1) {
        *error = [NSError errorWithDomain:[NSString stringWithFormat:@"映射到%@容错方法", self.scheme]
                                     code:TFY_RouterMStatusCanPerformFaultTolerance
                                 userInfo:nil];

        className = [NSString stringWithFormat:@"%@", [RouterMErrorAction.allKeys firstObject]];
        actionName = RouterMErrorAction[className];
    }
    
    /** 赋值 */
    *toClassNamePoint = className;
    *toActionNamePoint = actionName;
}

/**
 处理*方法
 
  host 路由协议
  className 类名
  actionName 方法名
  starSelectors *方法存放
  error 错误
 */
- (void)tfy_handlerStarMethodHost:(NSString *)host
                    className:(NSString *)className
                   actionName:(NSString *)actionName
             selectorsContain:(NSMutableDictionary *)starSelectors
                        error:(inout NSError **)error {
    if (starSelectors && [starSelectors isKindOfClass:[NSMutableDictionary class]]) {
        NSString *starHost = [@"/" stringByAppendingPathComponent:[host stringByAppendingPathComponent:@"*"]];
        NSString *starClass = [@"/" stringByAppendingPathComponent:[className stringByAppendingPathComponent:@"*"]];
        /** 注册了简称*方法 */
        [starSelectors setValue:RouterMQuickLookAction[starHost] forKey:RouterMHandlerStarHostActionKey];
        /** 注册了类称*方法 */
        [starSelectors setValue:RouterMQuickLookAction[starClass] forKey:RouterMHandlerStarClassActionKey];
        /** 大于0意味着有值存入，代表注册过*方法 */
        if (starSelectors.count > 0) {
            if (error) {
                *error = [NSError errorWithDomain:[NSString stringWithFormat:@"【%@】Selector不正确，但可以执行*方法", actionName]
                                             code:TFY_RouterMStatusCanPerformStarAction
                                         userInfo:nil];
            }
        }
    }
}

/**
 本地组件调用入口
 
  url       组件Url
  parameters      方法参数
 
 @return 实例对象
 */
- (id)tfy_performUrl:(NSString *)url
      parameters:(NSDictionary *)parameters
       forRouter:(TFY_RouterM *)router {
    NSURL *URL = [NSURL URLWithString:[url stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    NSString *className = URL.host;
    NSString *actionName = URL.path;
    NSError *error;
    id target;
    id completionObject;
    
    NSMutableDictionary *starSelectors = [NSMutableDictionary dictionary];
    [self tfy_canPerFormClass:&className action:&actionName error:&error target:&target star:starSelectors];
    
    /** 路由将要开始处理 */
    if ([router.delegate respondsToSelector:@selector(tfy_router:willHandlerUrl:parameters:)]) {
        if (![router.delegate tfy_router:router willHandlerUrl:url parameters:parameters]) {
            /** 调用者停止了路由 */
            error = [NSError errorWithDomain:[NSString stringWithFormat:@"调用者停止了路由[%@]流程", url]
                                        code:TFY_RouterMStatusUserCancelHandler
                                    userInfo:nil];
        }
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    BOOL canRunStarMethod = YES;
    /** 可以执行*方法，走进该方法，则target必不为空 */
    if (error.code == TFY_RouterMStatusCanPerformStarAction && starSelectors.count > 0) {
        /** 默认先执行简称*方法 */
        NSString *starSelector = [starSelectors valueForKey:RouterMHandlerStarHostActionKey];
        if (!starSelector) {
            /** 若没有简称*方法，则取类称*方法 */
            starSelector = [starSelectors valueForKey:RouterMHandlerStarClassActionKey];
        }
        /** 处理*方法 */
        if ([router.delegate respondsToSelector:@selector(tfy_router:willHandlerStarUrl:parameters:selector:)]) {
            canRunStarMethod = [router.delegate tfy_router:router willHandlerStarUrl:url parameters:parameters selector:starSelector];
        }
        
        if (canRunStarMethod && starSelector) {
            /** 如果可执行*方法，放在外面的原因是因为外部可以对selector进行修改 */
            //获取类的实例对象
            
            if ([target respondsToSelector:NSSelectorFromString(starSelector)]) {
                completionObject = [target performSelector:NSSelectorFromString(starSelector)
                                                withObject:url
                                                withObject:parameters];
                /** 同时清空error记录 */
                error = nil;
            } else {
                error = [NSError errorWithDomain:[NSString stringWithFormat:@"未找到*方法[%@]", starSelector]
                                            code:TFY_RouterMStatusNotFoundAction
                                        userInfo:nil];
            }
        }
    } else if (error.code == TFY_RouterMStatusCanPerformFaultTolerance ) {
        if (!completionObject) {
            canRunStarMethod = NO;
            error = nil;
            if ([target respondsToSelector:NSSelectorFromString(actionName)]) {
                completionObject = [target performSelector:NSSelectorFromString(actionName)
                                                withObject:url
                                                withObject:parameters];
            }
        }
    }
    
    /** 这里已经处理了*方法的错误 */
    if (error) {
        /** 路由调用处理失败 */
        if ([router.delegate respondsToSelector:@selector(tfy_router:failHandlerUrl:parameters:error:)]) {
            [router.delegate tfy_router:router failHandlerUrl:url parameters:parameters error:error];
        }
        RouterMHandlerLog(@"错误: %@", error.domain);
        return nil;
    }
    
    /** 如果为非空则走过*方法 */
    if (!completionObject && canRunStarMethod) {
        if ([target respondsToSelector:NSSelectorFromString(actionName)]) {
            completionObject = [target performSelector:NSSelectorFromString(actionName)
                                            withObject:parameters];
        }
    }
#pragma clang diagnostic pop
    //执行方法
    return completionObject;
}

/**
 获取类名

  string 类名
 @return 类名
 */
- (NSString *)tfy_getClassString:(NSString *)string {
    if ([self.classPrefix length]) {
        return [NSString stringWithFormat:@"%@%@", self.classPrefix, string];
    }else{
        return [NSString stringWithFormat:@"%@", string];
    }
}

#pragma mark - Public -- 公有方法

/**
 获取指定Controller名称的Controller
 
  controllerName 控制器名称
  error 错误
 @return 控制器实例
 */
+ (UIViewController *)tfy_handlerStringConvertToController:(NSString *)controllerName
                                                 error:(inout NSError *)error {
    
    if (![controllerName length]) {
        if (error != NULL) {
            error = [NSError errorWithDomain:[NSString stringWithFormat:@"[%@]名称不能为空", controllerName]
                                         code:TFY_RouterMStatusInputIsNull
                                     userInfo:nil];
        }
        return nil;
    }
    
    UIViewController *controller = [NSClassFromString(controllerName) new];
    if (controller) {
        /** 如果不是控制器类型，类型错误 */
        if (![controller isKindOfClass: [UIViewController class]]) {
            if (error != NULL) {
                error = [NSError errorWithDomain:[NSString stringWithFormat:@"[%@]控制器类型错误", controllerName]
                                             code:TFY_RouterMStatusErrorController
                                         userInfo:nil];
            }
            controller = nil;
        }
    } else {
        if (error != NULL) {
            error = [NSError errorWithDomain:[NSString stringWithFormat:@"未找到控制器[%@]", controllerName]
                                         code:TFY_RouterMStatusNotFoundController
                                     userInfo:nil];
        }
    }
    return controller;
}

/**
 添加便捷访问入口
 
  quickName 便捷访问地址
  className 映射地址
 */

- (void)tfy_handlerRegisterQuickName:(NSString *)quickName
                        forClass:(NSString *)className{
    NSAssert([quickName length], @"参数[quickName]格式不对，长度必须大于0");
    NSAssert([className length], @"参数[className]格式不对，长度必须大于0");
    if (self.ignoredCase) {
        quickName = [quickName lowercaseString];
    }
    [RouterMQuickLookClass setObject:className
                                forKey:quickName];
}

/**
 添加便捷访问入口
 
  quickName 便捷访问地址
  actionName 映射地址
 */
- (void)tfy_handlerRegisterQuickName:(NSString *)quickName
                       forAction:(NSString *)actionName{
    NSAssert([quickName length], @"参数[quickName]格式不对，长度必须大于0");
    NSAssert([actionName length], @"参数[actionName]格式不对，长度必须大于0");
    NSAssert(![quickName isEqualToString:@"*"], @"[*]方法无法直接注册，请使用简称或类称注册*方法");
    if ([quickName containsString:@"*"]) {
        NSArray *array = [actionName componentsSeparatedByString:@":"];
        NSAssert(array.count == 3, @"[*]方法必须有两个参数");
    }
    if (self.ignoredCase) {
        quickName = [quickName lowercaseString];
    }
    [RouterMQuickLookAction setObject:actionName
                                 forKey:[@"/" stringByAppendingPathComponent:quickName]];
}

/**
 通过路由获取执行结果
 
  url 路由协议，不响应http/https协议，需要提前注册
  parameters 参数，url中的参数会替换parameters中的参数
 @return 执行结果
 */
- (id)tfy_handlerResponseWithUrl:(NSString *)url
                  parameters:(NSDictionary * _Nullable)parameters
                   forRouter:(TFY_RouterM *)router {
    /** 添加重定向记录，防止循环重定向 */
    [RouterMHandlerRedirectLogs addObject:url];
    NSURL *URL = [NSURL URLWithString:[url stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    /** 获取传参 */
    NSMutableDictionary *realParameters = [parameters mutableCopy];
    if (!realParameters) {
        realParameters = [[NSMutableDictionary alloc] init];
    }
    /** 获取url请求参数，并添加到传参中，会替换传参中的重复参数 */
    NSString* urlQuery = [[URL query] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    for (NSString *urlParameter in [urlQuery componentsSeparatedByString:@"&"]) {
        NSArray *elements = TFY_RouterMURLQueryFormat(urlParameter);
        [realParameters setObject:[elements lastObject] forKey:[elements firstObject]];
    }
    /** 参数处理结束 */
    if ([router.delegate respondsToSelector:@selector(tfy_router:endHandlerParameters:forUrl:)]) {
        [router.delegate tfy_router:router endHandlerParameters:realParameters forUrl:url];
    }
    /** 执行路由主逻辑 */
    id completionObject = [self tfy_performUrl:url parameters:realParameters forRouter:router];
    /**
     支持redirect-xxx协议跳转
     */
    if ([completionObject isKindOfClass:[NSString class]]) {
        NSURL *redirectURL = [NSURL URLWithString:completionObject];
        if ([redirectURL.scheme containsString:@"redirect-"]) {
            NSString *redirectScheme = [redirectURL.scheme stringByReplacingOccurrencesOfString:@"redirect-" withString:@""];
            NSString *routerUrl = [completionObject stringByReplacingOccurrencesOfString:redirectURL.scheme withString:redirectScheme];
            if ([RouterMHandlerRedirectLogs containsObject:routerUrl]) {
                /** 如果包含了重定向链接，会产生死循环，处理方式不允许跳 */
    
                /** 路由协议未注册，调用处理失败 */
                NSString *errorDomain = [NSString stringWithFormat:@"[%@]在重定向路径[%@]中循环调用", url, RouterMHandlerRedirectLogs];
                if ([router.delegate respondsToSelector:@selector(tfy_router:failHandlerUrl:parameters:error:)]) {
                    [router.delegate tfy_router:router failHandlerUrl:url parameters:parameters error:[NSError errorWithDomain:errorDomain  code:TFY_RouterMStatusRedirectUrlCycles userInfo:@{@"currentUrl":completionObject,@"redirectUrls":[RouterMHandlerRedirectLogs copy],}]];
                }
                RouterMHandlerLog(@"错误: %@", errorDomain);
                [RouterMHandlerRedirectLogs removeAllObjects];
                return nil;
            }
            
            /** 路由重定向 */
            BOOL canRedirect = YES;
            if ([router.delegate respondsToSelector:@selector(tfy_router:redirectUrl:toUrl:allRedirects:parameters:)]) {
                canRedirect = [router.delegate tfy_router:router redirectUrl:url toUrl:routerUrl allRedirects:[RouterMHandlerRedirectLogs copy] parameters:parameters];
            }
            if (canRedirect) {
                return [self tfy_handlerResponseWithUrl:routerUrl
                                         parameters:parameters
                                          forRouter:router];
            }
        }
    }
    [RouterMHandlerRedirectLogs removeAllObjects];
    return completionObject;
}

/**
 链接是否可以进行原生跳转，不会检测*方法
 
  url 链接
 */
- (BOOL)tfy_canHandlerOpenURL:(NSString *)url {
    NSURL *URL = [NSURL URLWithString:url];
    /** 获取Url解析的Class名称 */
    NSString *className = [URL.host copy];
    
    /** 获取url解析的Selector名称 */
    NSString *actionName = [URL.path copy];
    return [self tfy_canPerFormClass:&className
                          action:&actionName
                           error:nil
                          target:nil
                            star:nil];
    
}

/**
 为handle注册容错方法
 
  className 映射地址
  actionName 映射方法， */
- (void)tfy_registerError:(NSString *)className
            forAction:(NSString *)actionName {
    if (className.length && actionName.length) {
        NSArray *array = [actionName componentsSeparatedByString:@":"];
        NSAssert(array.count == 3, @"[*]方法必须有两个参数");
        if (self.actionPrefix.length && [actionName hasPrefix:self.actionPrefix]) {
            actionName = [actionName stringByReplacingOccurrencesOfString:self.actionPrefix withString:@""];
        }
        NSString *action = actionName;

        if ([actionName hasSuffix:@":"] && actionName.length > 1) {
            action = [actionName substringToIndex:(action.length -1)];
        }
        RouterMErrorAction = @{className : action ? : @""};
    }
}


@end

/**
 用于执行finish回调
 */
@implementation NSObject (RouterMExtension)

#pragma mark - Define&StaticVar -- 静态变量和Define声明
/** 回调存储key */
static const char RouterMFinishCompletionBlockRuntimeKey;

/**
 添加回调方法
 finishBlock 回调方法
 */
- (void)tfy_routerm_addFinishCompletionBlock:(TFY_RouterMFinishCompletionBlock)finishBlock{
    objc_setAssociatedObject(self, &RouterMFinishCompletionBlockRuntimeKey, finishBlock, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

/**
 执行回调方法
 finishObject 回调数据
 */
- (void)tfy_routerm_performFinishCompletionBlock:(id)finishObject;{
    TFY_RouterMFinishCompletionBlock finish = objc_getAssociatedObject(self, &RouterMFinishCompletionBlockRuntimeKey);
    if (finish) {
        finish(finishObject);
    }
}

@end
