//
//  TFY_RouterM.h
//  TFY_MessageMKit
//
//  Created by 田风有 on 2020/8/23.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@class TFY_RouterM;

NS_ASSUME_NONNULL_BEGIN

/**
 获取格式化后的Url参数

  queryElementsString 待格式化的参数
  格式化后的参数
 */
NSArray * _Nonnull TFY_RouterMURLQueryFormat(NSString * _Nonnull queryElementsString);

#pragma mark - Define&StaticVar -- 静态变量和Define声明
/**
 路由代理，用于监听控制路由过程状态，对于block注册的路由只监听部分状态
 */
@protocol TFY_RouterMStatusDelegate <NSObject>

@optional
/**
 路由开始处理

  router 路由实例
  url 路由协议链接
  parameters 参数
 */
- (void)tfy_router:(TFY_RouterM *)router beginHandlerUrl:(NSString *)url parameters:(NSDictionary *)parameters;

/**
 路由将要开始处理
 
  router 路由实例
  url 路由协议链接
  parameters 参数
  是否允许路由继续处理
 */
- (BOOL)tfy_router:(TFY_RouterM *)router willHandlerUrl:(NSString *)url parameters:(NSDictionary *)parameters;

/**
 路由处理失败，不监听block路由

  router 路由实例
  url 路由协议链接
  parameters 参数
  error 错误
 */
- (void)tfy_router:(TFY_RouterM *)router failHandlerUrl:(NSString *)url parameters:(NSDictionary *)parameters error:(NSError *)error;

/**
 路由处理成功

  router 路由实例
  url 路由协议链接
  parameters 参数
 */
- (void)tfy_router:(TFY_RouterM *)router didHandlerUrl:(NSString *)url parameters:(NSDictionary *)parameters;

/**
 路由参数处理结束，不监听block路由

  router 路由实例
  realParameters 最终参数，该参数内容可以修改，并会传递到最终路由处理中
  url 路由协议链接
 */
- (void)tfy_router:(TFY_RouterM *)router endHandlerParameters:(NSMutableDictionary *)realParameters forUrl:(NSString *)url;

/**
 路由重定向，不监听block路由

  router 路由实例
  sourceUrl 原路由协议链接
  toUrl 重定向路由协议链接
  redirectUrls 本次重定向路过的所有路径
  parameters 参数
  是否允许重定向
 */
- (BOOL)tfy_router:(TFY_RouterM *)router redirectUrl:(NSString *)sourceUrl toUrl:(NSString *)toUrl allRedirects:(NSArray *)redirectUrls parameters:(NSDictionary *)parameters;

/**
 路由处理结束后，将要添加finish处理块

  router 路由实例
  url 路由协议链接
  parameters 参数
  completionObject 路由处理结果
  是否允许添加finish块
 */
- (BOOL)tfy_router:(TFY_RouterM *)router willAddFinishToUrl:(NSString *)url parameters:(NSDictionary *)parameters forObject:(id)completionObject;

/**
 路由监听到*方法要执行，不监听block路由

  router 路由实例
  url 路由协议链接
  parameters 参数
  selectorPoint 执行Selector字符串对应的指针，指针对象，若为空，则为之前注册的方法，使用*selectorPoint = @"method:";来修改;
  是否允许执行*方法
 */
- (BOOL)tfy_router:(TFY_RouterM *)router willHandlerStarUrl:(NSString *)url parameters:(NSDictionary *)parameters selector:(inout NSString * _Nullable)selectorPoint;

/**
 路由处理结束，如果注册过completion，将执行completion块

  router 路由实例
  completionObject 处理结果
  url 路由协议链接
  parameters 参数
  是否允许执行最终completion块
 */
- (BOOL)tfy_router:(TFY_RouterM *)router willRunCompletion:(id)completionObject hasHandlerUrl:(NSString *)url parameters:(NSDictionary *)parameters;

@end

/**
 路由错误代码

 - TFY_RouterMStatusNotRegisterScheme: 路由Scheme未注册
 - TFY_RouterMStatusNotFoundClass: 找不到类
 - TFY_RouterMStatusNotFoundAction: 找不到方法
 - TFY_RouterMStatusUserCancelHandler: 用户取消操作
 - TFY_RouterMStatusCanPerformStarAction: 可执行*方法
 - TFY_RouterMStatusCanPerformStarAction: 可执行*方法
 - TFY_RouterMStatusCanPerformFaultTolerance: 容错的方法
 */
typedef NS_ENUM(NSUInteger, TFY_RouterMStatusCode) {
    TFY_RouterMStatusInputIsNull = 262004,
    TFY_RouterMStatusNotRegisterScheme = 262300,
    TFY_RouterMStatusErrorController = 262502,
    TFY_RouterMStatusNotFoundController = 262501,
    TFY_RouterMStatusNotFoundClass = 262500,
    TFY_RouterMStatusNotFoundAction = 262404,
    TFY_RouterMStatusRedirectUrlCycles = 262302,
    TFY_RouterMStatusUserCancelHandler = 262002,
    TFY_RouterMStatusCanPerformStarAction = 262001,
    TFY_RouterMStatusCanPerformFaultTolerance = 262002,

};

/**
 路由运行后的回调

  completionObject 回调数据
 */
typedef void (^TFY_RouterMCompletionBlock)(id _Nullable completionObject);

/**
 路由执行者的回调

  finishObject 回调数据
 */
typedef void (^TFY_RouterMFinishCompletionBlock)(id _Nullable finishObject);

/**
 快速注册回调

  url 路由协议
  parameters 参数
  处理结果，与完成回调参数保持一致
 */
typedef id _Nonnull (^TFY_RouterMRegisterHandlerBlock)(NSString *url, NSDictionary * _Nullable parameters);

/**
 回调协议
 */
@protocol TFY_RouterMFinishCompletionProtocol <NSObject>

@optional
/**
 执行回调方法
 
  finishObject 回调数据
 */
- (void)tfy_routerm_performFinishCompletionBlock:(id)finishObject;


@end


/**
 路由控制中心
 
 @log 现在TFY_RouterM实现方法支持redirect协议转发。
    redirect-scheme://host/path    scheme即为要转发的协议
 */
@interface TFY_RouterM : NSObject

#pragma mark - Property -- 属性声明
/** 是否开启调试 */
@property(class, nonatomic, assign)BOOL debug;

/** 路由代理，用于监听修正路由各个状态 */
@property(nonatomic, strong)id<TFY_RouterMStatusDelegate> delegate;


#pragma mark - Function -- 方法

/**
 单例路由
 */
+ (instancetype)router;

/**
 获取指定Controller名称的Controller
 */
+ (UIViewController *)tfy_stringConvertToController:(NSString *)controllerString;

/**
 注册TFY_RouterM，默认不忽略注册链接的大小写
 
  scheme 路由协议
  classPrefix 最终生成的类前缀
  actionPreFix 最终生成的方法前缀
 */
- (void)tfy_registerScheme:(NSString *)scheme
           classPrefix:(NSString * _Nullable)classPrefix
          actionPreFix:(NSString * _Nullable)actionPreFix;

/**
 注册TFY_RouterM
 
  scheme 路由协议
  classPrefix 最终生成的类前缀
  actionPreFix 最终生成的方法前缀
  ignored 是否忽略注册链接的大小写，常用于http协议注册，大小写忽略仅限于路由协议，最终的selector方法依然大小写敏感
 */
- (void)tfy_registerScheme:(NSString *)scheme
           classPrefix:(NSString * _Nullable)classPrefix
          actionPreFix:(NSString * _Nullable)actionPreFix
           ignoredCase:(BOOL)ignored;


/**
 将协议映射到另一个已注册的协议，两个协议将共用一个handler，之后的所有注册逻辑都会实时同步，可用于http和https两个协议映射，该方法不会映射通过block注册的url协议

  scheme 路由协议
  targetScheme 要映射的协议
 */
- (void)tfy_remoteScheme:(NSString *)scheme
      toTargetScheme:(NSString *)targetScheme;

/**
 添加便捷类映射
 
  quickName 便捷访问地址
  className 映射地址
  scheme 协议
 */

- (void)tfy_registerQuickName:(NSString *)quickName
                 forClass:(NSString *)className
                 atScheme:(NSString *)scheme;

/**
 注册scheme的容错方法，类似已*方法的调用，同一scheme只能有一个容错方法
 
  className 映射地址
  actionName 映射方法，
  scheme 协议
 *方法对应的映射方法必须为双参数，第一个参数为url，第二个参数为parameters，可以不加前缀, 必须带:
 */
- (void)tfy_registerError:(NSString *)className
            forAction:(NSString *)actionName
               scheme:(NSString *)scheme;

/**
 添加便捷方法映射，可以注册*方法，必须使用[host/ * ]获取[class/ * ]来注册，*方法注册不支持全局注册   同一个类中只允许有一个*方法
 
  quickName 便捷访问地址
  actionName 映射方法，
    普通方法为单参数，不需要加:；例：detail
    *方法对应的映射方法必须为双参数，第一个参数为url，第二个参数为parameters，需要两个;例：handler:parameters:
  scheme 协议
 */
- (void)tfy_registerQuickName:(NSString *)quickName
                forAction:(NSString *)actionName
                 atScheme:(NSString *)scheme;

/**
 为scheme注册路由协议
 
  url 路由协议
  handler 路由回调，如果为空则注册失败
 */
- (void)tfy_registerUrl:(NSString *)url
            handler:(TFY_RouterMRegisterHandlerBlock _Nullable)handler;

/**
 执行路由跳转，返回值支持redirect-xxx协议快速跳转，重定向不支持block路由

  url 路由协议
  parameters 参数，url中的参数会替换parameters中的参数
  completion 路由回调
  finish 路由执行者的回调
 */
- (void)tfy_openUrl:(NSString *)url
     parameters:(NSDictionary * _Nullable)parameters
     completion:(TFY_RouterMCompletionBlock _Nullable)completion
         finish:(TFY_RouterMFinishCompletionBlock _Nullable)finish;

/**
 执行路由跳转，返回值支持redirect-xxx协议快速跳转，重定向不支持block路由
 
  url 路由协议
  parameters 参数，url中的参数会替换parameters中的参数
  completion 路由回调
 */
- (void)tfy_openUrl:(NSString *)url
     parameters:(NSDictionary * _Nullable)parameters
     completion:(TFY_RouterMCompletionBlock _Nullable)completion;

/**
 通过路由获取执行结果，返回值支持redirect-xxx协议快速跳转，重定向不支持block路由
 
  url 路由协议
  parameters 参数，url中的参数会替换parameters中的参数
  finish 路由执行者的回调
  执行结果
 */
- (id)tfy_responseWithUrl:(NSString *)url
           parameters:(NSDictionary * _Nullable)parameters
               finish:(TFY_RouterMFinishCompletionBlock _Nullable)finish;

/**
 通过路由获取执行结果，返回值支持redirect-xxx协议快速跳转，重定向不支持block路由
 
  url 路由协议，响应http/https协议，需要提前注册
  parameters 参数，url中的参数会替换parameters中的参数
  执行结果
 */
- (id)tfy_responseWithUrl:(NSString *)url
           parameters:(NSDictionary * _Nullable)parameters;

/**
 链接是否可以进行原生跳转，不会判定*方法
 
  url 链接
 */
- (BOOL)tfy_canOpenURL:(NSString *)url;

@end

NS_ASSUME_NONNULL_END

