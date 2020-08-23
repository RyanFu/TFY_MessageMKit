//
//  NSObject+TFY_MessageE.h
//  TFY_MessageMKit
//
//  Created by 田风有 on 2020/8/23.
//

#import <Foundation/Foundation.h>
#import "TFY_MessageM.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (TFY_MessageE)
/**
 开始接收消息

 message 消息名称
 selector 接收后执行的方法
 */
- (void)tfy_message_listenMessage:(NSString *)message selector:(SEL)selector;


/**
 开始接受消息

  message 消息名称
  block 接收后执行的回调
 */
- (void)tfy_message_listenMessage:(NSString *)message usingBlock:(nullable MessageMCompletionBlock)block;


/**
 移除消息接收
 
  message 消息
 */
- (void)tfy_message_deListenMessage:(NSString *)message;

/**
 发送消息

  message 消息名称
  object 消息发送内容
 */
- (void)tfy_message_sendMessage:(NSString *)message object:(nullable id)object;

/**
 发送消息
 
  message 消息名称
  object 消息发送内容
  userInfo 附属内容
 */
- (void)tfy_message_sendMessage:(NSString *)message object:(nullable id)object userInfo:(nullable NSDictionary *)userInfo;

@end

NS_ASSUME_NONNULL_END
