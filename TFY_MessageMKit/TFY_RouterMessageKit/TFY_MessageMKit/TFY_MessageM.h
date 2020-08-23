//
//  TFY_MessageM.h
//  TFY_MessageMKit
//
//  Created by 田风有 on 2020/8/23.
//

#import <Foundation/Foundation.h>

@class TFY_MessageData;

NS_ASSUME_NONNULL_BEGIN

/**
 消息处理回调    message 回调数据
 */
typedef void (^MessageMCompletionBlock)(TFY_MessageData * _Nullable message);

@interface TFY_MessageM : NSObject
/**
 单例消息中心
 */
+ (instancetype)message;

/**
 添加消息接收者
 listener 消息接收者
 message 消息
 selector 执行方法，【@selector(method:)参数为消息内容，参数可以省略】
 */
- (void)addListener:(id)listener
         forMessage:(NSString *)message
           selector:(SEL)selector;


/**
 添加消息接收者
 listener 消息接收者
 message 消息
 block 执行回调
 */
- (void)addListener:(id)listener
         forMessage:(NSString *)message
         usingBlock:(nullable MessageMCompletionBlock)block;


/**
 移除消息接收者
 listener 消息接收者
 message 消息
 */
- (void)removeListener:(id)listener
            forMessage:(NSString *)message;


/**
 发送消息
 message 消息
 object 消息发送内容
 */
- (void)sendMessage:(NSString *)message
             object:(nullable id)object;


/**
 发送消息
 message 消息
 object 消息发送内容
 userInfo 附属内容
 */
- (void)sendMessage:(NSString *)message
             object:(nullable id)object
           userInfo:(nullable NSDictionary *)userInfo;
@end

@interface TFY_MessageData : NSObject

/** 消息名称 */
@property(nonatomic, copy, readonly)NSString *name;

/** 消息体 */
@property(nonatomic, strong, readonly)id object;

/** 消息附属内容 */
@property(nonatomic, copy, readonly)NSDictionary *userInfo;
/**
 初始化消息
 name 名称
 object 消息体
 userInfo 附属内容
 */
- (instancetype)initWithName:(NSString *)name object:(nullable id)object userInfo:(nullable NSDictionary *)userInfo;
/**
 初始化消息
 name 名称
 object 消息体
 userInfo 附属内容
 */
+ (instancetype)messageWithName:(NSString *)name object:(nullable id)object userInfo:(nullable NSDictionary *)userInfo;

/**
 初始化消息
 name 名称
 object 消息体
 */
+ (instancetype)messageWithName:(NSString *)name object:(nullable id)object;
@end


NS_ASSUME_NONNULL_END
