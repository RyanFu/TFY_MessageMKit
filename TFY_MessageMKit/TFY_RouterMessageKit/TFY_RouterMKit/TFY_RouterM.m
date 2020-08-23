//
//  TFY_RouterM.m
//  TFY_MessageMKit
//
//  Created by 田风有 on 2020/8/23.
//

#import "TFY_RouterM.h"
#import "TFY_RouterMHandler.h"

#pragma mark - Define&StaticVar -- 静态变量和Define声明

/**
 获取格式化后的Url参数
 
  queryElementsString 待格式化1
  格式化后的参数
 */
NSArray *TFY_RouterMURLQueryFormat(NSString *queryElementsString) {
    NSArray *queryElements = [queryElementsString componentsSeparatedByString:@"="];
    if([queryElements count] < 2) {
        queryElements = [NSArray arrayWithObjects:[queryElements firstObject], @"", nil];
    }
    if ([queryElements count] > 2) {
        // 防止参数中含有=
        NSMutableArray *temp = [queryElements mutableCopy];
        [temp removeObjectAtIndex:0];
        queryElements = [NSArray arrayWithObjects:[queryElements firstObject], [temp componentsJoinedByString:@"="], nil];
    }
    return queryElements;
}

/** Debug模式打印Log信息 */
#ifdef DEBUG
#define TFY_RouterLog(...) !TFY_RouterM.debug ? : NSLog(@"\n%s 第%d行: \n %@\n\n",__func__,__LINE__,[NSString stringWithFormat:__VA_ARGS__])
#else
#define TFY_RouterLog(...)
#endif

/** 为了支撑类属性 */
static BOOL _debug = NO;

@interface TFY_RouterM ()
/** 所有注册url的记录 */
@property(nonatomic, strong)NSMutableArray *registerUrls;
/** 通过block注册的记录 */
@property(nonatomic, strong)NSMutableDictionary *quickHandlers;
/** 路由处理协议 */
@property(nonatomic, strong)NSMutableDictionary *handlers;
@end

@implementation TFY_RouterM

#pragma mark - Life Circle -- 生命周期和初始化设置

/**
 单例路由
 */
+ (instancetype)router {
    static id sharedRouterM;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedRouterM = [[self alloc] init];
    });
    return sharedRouterM;
}
/**
 初始化
 */
- (instancetype)init{
    self = [super init];
    if (self) {
        _registerUrls = [NSMutableArray array];
        _quickHandlers = [NSMutableDictionary dictionary];
        _handlers = [NSMutableDictionary dictionary];
    }
    return self;
}
#pragma mark - Getter&Setter -- 懒加载

+ (BOOL)debug {
    return _debug;
}

+ (void)setDebug:(BOOL)debug {
    _debug = debug;
}

#pragma mark - Private -- 私有方法


/**
 通过url获取handler

  url url链接
  路由处理
 */
- (TFY_RouterMHandler *)tfy_handlerForUrl:(NSString *)url {
    /** 获取Host */
    NSURL *URL = [NSURL URLWithString:[url stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    return [self.handlers valueForKey:URL.scheme];
}


/**
 过滤Url的参数，只留下scheme://host/path

  url 待过滤的链接
  过滤后的链接
 */
- (NSString *)tfy_filterUrlParameters:(NSString *)url {
    NSURL *URL = [NSURL URLWithString:[url stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    return [NSString stringWithFormat:@"%@://%@%@", URL.scheme, URL.host, URL.path];
}


/**
 通过路由获取执行结果
 
  url 路由协议，不响应http/https协议，需要提前注册
  parameters 参数，url中的参数会替换parameters中的参数
  finish 路由执行者的回调
  执行结果
 */
- (id)tfy_responseWithUrl:(NSString *)url
           parameters:(NSDictionary * _Nullable)parameters
           completion:(TFY_RouterMCompletionBlock _Nullable)completion
               finish:(TFY_RouterMFinishCompletionBlock _Nullable)finish {
    /** 路由开始处理 */
    if ([self.delegate respondsToSelector:@selector(tfy_router:beginHandlerUrl:parameters:)]) {
        [self.delegate tfy_router:self beginHandlerUrl:url parameters:parameters];
    }
    id completionObject;
    NSError *error;
    
    /** 判定是否为链接，这里也判定了url是否为空 */
    if (![url containsString:@"://"]) {
        /** 执行返回控制器逻辑 */
        /** 路由将要开始处理 */
        if ([self.delegate respondsToSelector:@selector(tfy_router:willHandlerUrl:parameters:)]) {
            if (![self.delegate tfy_router:self willHandlerUrl:url parameters:parameters]) {
                /** 调用者停止了路由 */
                error = [NSError errorWithDomain:[NSString stringWithFormat:@"调用者停止了路由[%@]流程", url]
                                            code:TFY_RouterMStatusUserCancelHandler
                                         userInfo:nil];
            }
        }
        if (!error) {
            completionObject = [TFY_RouterMHandler tfy_handlerStringConvertToController:url error:error];
        }
    }
    /** 表示未执行直接打开控制器逻辑 */
    if ((!error) && (!completionObject)) {
        /** 获取过滤后的Url */
        NSString *realUrl = [self tfy_filterUrlParameters:url];
        
        /** 是否快速注册过，快速注册过则肯定注册过 */
        if ([self.quickHandlers.allKeys containsObject:realUrl]) {
            TFY_RouterMRegisterHandlerBlock handlerBlock = [self.quickHandlers valueForKey:realUrl];
            /** 路由将要开始处理 */
            if ([self.delegate respondsToSelector:@selector(tfy_router:willHandlerUrl:parameters:)]) {
                if (![self.delegate tfy_router:self willHandlerUrl:url parameters:parameters]) {
                    /** 调用者停止了路由 */
                    error = [NSError errorWithDomain:[NSString stringWithFormat:@"调用者停止了路由[%@]流程", url]
                                                code:TFY_RouterMStatusUserCancelHandler
                                            userInfo:nil];
                }
            }
            completionObject = handlerBlock(url, parameters);
        } else {
            /** 判定是否注册过 */
            TFY_RouterMHandler *handler = [self tfy_handlerForUrl:realUrl];
            if (handler) {
                completionObject = [handler tfy_handlerResponseWithUrl:url
                                                        parameters:parameters
                                                         forRouter:self];
            } else {
                /** 路由协议未注册 */
                error = [NSError errorWithDomain:[NSString stringWithFormat:@"[%@]路由协议未注册", url]
                                            code:TFY_RouterMStatusNotRegisterScheme
                                        userInfo:nil];
            }
        }
        
    }
    
    if (error) {
        /** 调用处理失败 */
        if ([self.delegate respondsToSelector:@selector(tfy_router:failHandlerUrl:parameters:error:)]) {
            [self.delegate tfy_router:self failHandlerUrl:url parameters:parameters error:error];
        }
        TFY_RouterLog(@"错误: %@", error.domain);
    }
    
    /** 路由处理成功 */
    if ([self.delegate respondsToSelector:@selector(tfy_router:didHandlerUrl:parameters:)]) {
        [self.delegate tfy_router:self didHandlerUrl:url parameters:parameters];
    }
    
    if (completion) {
        /** 执行路由completion块 */
        BOOL canRunCompletion = YES;
        if ([self.delegate respondsToSelector:@selector(tfy_router:willRunCompletion:hasHandlerUrl:parameters:)]) {
            canRunCompletion = [self.delegate tfy_router:self willRunCompletion:completionObject hasHandlerUrl:url parameters:parameters];
        }
        if (canRunCompletion) {
            completion(completionObject);
        }
    }
    
    if (finish) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
        /** 判断是否实现了tfy_routerm_addFinishCompletionBlock方法，如果实现，则执行 */
        if ([completionObject respondsToSelector:@selector(tfy_routerm_addFinishCompletionBlock:)]) {
            BOOL canAddFinishBlock = YES;
            if ([self.delegate respondsToSelector:@selector(tfy_router:willAddFinishToUrl:parameters:forObject:)]) {
                canAddFinishBlock = [self.delegate tfy_router:self willAddFinishToUrl:url parameters:parameters forObject:completionObject];
            }
            if (canAddFinishBlock) {
                [completionObject performSelector:@selector(tfy_routerm_addFinishCompletionBlock:) withObject:finish];
            }
        }
#pragma clang diagnostic pop
    }
    
    return completionObject;
}

#pragma mark - Override -- 重写方法


#pragma mark - Public -- 公有方法

/**
 获取指定Controller名称的Controller
 */
+ (UIViewController *)tfy_stringConvertToController: (NSString *)controllerString{
    return [TFY_RouterMHandler tfy_handlerStringConvertToController:controllerString error:nil];
}


/**
 注册TFY_Router
 
  scheme scheme
  classPrefix classPrefix
  actionPreFix actionPreFix
 */
- (void)tfy_registerScheme:(NSString *)scheme
           classPrefix:(NSString * _Nullable)classPrefix
          actionPreFix:(NSString * _Nullable)actionPreFix {
    [self tfy_registerScheme:scheme classPrefix:classPrefix actionPreFix:actionPreFix ignoredCase:NO];
}

/**
 注册TFY_Router
 
  scheme scheme
  classPrefix classPrefix
  actionPreFix actionPreFix
  ignored 是否忽略注册链接的大小写，常用于http协议注册
 */
- (void)tfy_registerScheme:(NSString *)scheme
           classPrefix:(NSString * _Nullable)classPrefix
          actionPreFix:(NSString * _Nullable)actionPreFix
           ignoredCase:(BOOL)ignored {
    /** 如果已经注册过 */
    NSAssert(![self.handlers.allKeys containsObject:scheme], @"协议[%@]已经注册过，无法重新注册", scheme);
    
    TFY_RouterMHandler *handler = [TFY_RouterMHandler tfy_handlerWithScheme:scheme
                                                        classPrefix:classPrefix
                                                       actionPreFix:actionPreFix
                                                        ignoredCase:ignored];
    [self.handlers setValue:handler forKey:scheme];
}

/**
 将协议映射到另一个已注册的协议，两个协议将共用一个handler，之后的所有注册逻辑都会实时同步，可用于http和https两个协议映射
 
  scheme 路由协议
  targetScheme 要映射的协议
 */
- (void)tfy_remoteScheme:(NSString *)scheme
      toTargetScheme:(NSString *)targetScheme {
    TFY_RouterMHandler *handler = [self.handlers valueForKey:targetScheme];
    /** 协议未注册过 */
    NSAssert(handler, @"协议[%@]未注册过协议，无法映射", targetScheme);
    [self.handlers setValue:handler forKey:scheme];
}

/**
 添加便捷类映射
 
  quickName 便捷访问地址
  className 映射地址
 */

- (void)tfy_registerQuickName:(NSString *)quickName
                 forClass:(NSString *)className
                 atScheme:(NSString *)scheme {
    TFY_RouterMHandler *handler = [self.handlers valueForKey:scheme];
    /** 协议未注册过 */
    NSAssert(handler, @"协议[%@]未注册过协议，无法注册", scheme);
    [handler tfy_handlerRegisterQuickName:quickName forClass:className];
}

/**
 注册scheme的错误防范
 
  className 映射地址
  actionName 映射方法，
  scheme 协议
 *方法对应的映射方法必须为双参数，第一个参数为url，第二个参数为parameters，需要两个;例：handler:parameters:
 */
- (void)tfy_registerError:(NSString *)className
            forAction:(NSString *)actionName
               scheme:(NSString *)scheme {
    
    TFY_RouterMHandler *handler = [self.handlers valueForKey:scheme];
    /** 协议未注册过 */
    NSAssert(handler, @"协议[%@]未注册过协议，无法注册", scheme);
    
    [handler tfy_registerError:className forAction:actionName];
}

/**
 添加便捷方法映射，可以注册*方法，必须使用[host/ * ]获取[class/ * ]来注册，*方法注册不支持全局注册
 
  quickName 便捷访问地址
  actionName 映射地址
 */
- (void)tfy_registerQuickName:(NSString *)quickName
                forAction:(NSString *)actionName
                 atScheme:(NSString *)scheme {
    TFY_RouterMHandler *handler = [self.handlers valueForKey:scheme];
    /** 协议未注册过 */
    NSAssert(handler, @"协议[%@]未注册过协议，无法注册", scheme);
    [handler tfy_handlerRegisterQuickName:quickName forAction:actionName];
}

/**
 为scheme注册路由协议
 
  url 路由协议
 */
- (void)tfy_registerUrl:(NSString *)url
            handler:(TFY_RouterMRegisterHandlerBlock)handlerBlock {
    TFY_RouterMHandler *handler = [self tfy_handlerForUrl:url];
    /** 协议未注册过 */
    NSAssert(handler, @"路由[%@]未注册过协议，无法注册", url);
    /** 获取过滤后的Url */
    NSString *realUrl = [self tfy_filterUrlParameters:url];
    /** 如果已经注册过 */
    NSAssert(![self.registerUrls containsObject:realUrl], @"路由[%@]已经注册过，无法重新注册", url);
    [self.registerUrls addObject:realUrl];
    if (handlerBlock) {
        /** 如果有block */
        if (handlerBlock) {
            [self.quickHandlers setObject:handlerBlock forKey:realUrl];
        }
    }
}

/**
 执行路由跳转
 
  url 路由协议，响应http/https协议，不过要提前注册
  parameters 参数
  completion 路由回调
  finish 路由执行者的回调
 */
- (void)tfy_openUrl:(NSString *)url
     parameters:(NSDictionary * _Nullable)parameters
     completion:(TFY_RouterMCompletionBlock _Nullable)completion
         finish:(TFY_RouterMFinishCompletionBlock _Nullable)finish;{
    [self tfy_responseWithUrl:url
               parameters:parameters
               completion:completion
                   finish:finish];
    
}
/**
 执行路由跳转
 
  url 路由协议，响应http/https协议，不过要提前注册
  parameters 参数
  completion 路由回调
 */
- (void)tfy_openUrl:(NSString *)url
     parameters:(NSDictionary * _Nullable)parameters
     completion:(TFY_RouterMCompletionBlock _Nullable)completion;{
    [self tfy_openUrl:url
       parameters:parameters
       completion:completion
           finish:nil];
}

/**
 通过路由获取执行结果
 
  url 路由协议，不响应http/https协议，需要提前注册
  parameters 参数，url中的参数会替换parameters中的参数
  finish 路由执行者的回调
  执行结果
 */
- (id)tfy_responseWithUrl:(NSString *)url
           parameters:(NSDictionary * _Nullable)parameters
               finish:(TFY_RouterMFinishCompletionBlock _Nullable)finish {
    return [self tfy_responseWithUrl:url
                      parameters:parameters
                      completion:nil
                          finish:finish];;
}

/**
 通过路由获取执行结果
 
  url 路由协议，响应http/https协议，需要提前注册
  parameters 参数，url中的参数会替换parameters中的参数
  执行结果
 */
- (id)tfy_responseWithUrl:(NSString *)url
           parameters:(NSDictionary * _Nullable)parameters {
    return [self tfy_responseWithUrl:url parameters:parameters finish:nil];
}

/**
 链接是否可以进行原生跳转
 
  url 链接
 */
- (BOOL)tfy_canOpenURL:(NSString *)url;{
    /** 获取过滤后的Url */
    NSString *realUrl = [self tfy_filterUrlParameters:url];
    
    /** 是否快速注册过，快速注册过则肯定注册过 */
    if ([self.quickHandlers.allKeys containsObject:realUrl]) {
        return YES;
    }
    /** 判定是否注册过 */
    TFY_RouterMHandler *handler = [self tfy_handlerForUrl:realUrl];
    return [handler tfy_canHandlerOpenURL:url];
}

#pragma mark - Delegate -- 代理方法，每个代理新建一个mark。

@end

