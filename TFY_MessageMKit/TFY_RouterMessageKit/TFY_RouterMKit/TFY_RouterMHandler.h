//
//  TFY_RouterMHandler.h
//  TFY_MessageMKit
//
//  Created by 田风有 on 2020/8/23.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class TFY_RouterM;


NS_ASSUME_NONNULL_BEGIN

@interface TFY_RouterMHandler : NSObject
#pragma mark - Property -- 属性声明

#pragma mark - Function -- 方法

/**
 获取指定Controller名称的Controller

  controllerName 控制器名称
  error 错误
  控制器实例
 */
+ (UIViewController *)tfy_handlerStringConvertToController:(NSString *)controllerName
                                                 error:(inout NSError * _Nullable)error;

/**
 生成实例
 
  scheme scheme
  classPrefix classPrefix
  actionPreFix actionPreFix
  ignored 是否忽略注册链接的大小写，常用于http协议注册
 */
+ (instancetype)tfy_handlerWithScheme:(NSString *)scheme
                      classPrefix:(NSString * _Nullable)classPrefix
                     actionPreFix:(NSString * _Nullable)actionPreFix
                      ignoredCase:(BOOL)ignored;

/**
 添加便捷访问入口
 
  quickName 便捷访问地址
  className 映射地址
 */

- (void)tfy_handlerRegisterQuickName:(NSString *)quickName
                        forClass:(NSString *)className;

/**
 添加便捷访问入口
 
  quickName 便捷访问地址
  actionName 映射地址
 */
- (void)tfy_handlerRegisterQuickName:(NSString *)quickName
                       forAction:(NSString *)actionName;

/**
 通过路由获取执行结果
 
  url 路由协议
  parameters 参数，url中的参数会替换parameters中的参数
  执行结果
 */
- (id)tfy_handlerResponseWithUrl:(NSString *)url
                  parameters:(NSDictionary * _Nullable)parameters
                   forRouter:(TFY_RouterM *)router;

/**
 链接是否可以进行原生跳转
 
  url 链接
 */
- (BOOL)tfy_canHandlerOpenURL:(NSString *)url;

/**
 为handle注册容错方法

  className 映射地址
  actionName 映射方法， */
- (void)tfy_registerError:(NSString *)className
            forAction:(NSString *)actionName;


@end

NS_ASSUME_NONNULL_END
