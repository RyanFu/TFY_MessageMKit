//
//  TFY_MessageM.m
//  TFY_MessageMKit
//
//  Created by 田风有 on 2020/8/23.
//

#import "TFY_MessageM.h"

/** 用于网络接口的线程锁 */
#define TFY_MessageMLock() dispatch_semaphore_wait(MessageMSemaphore, DISPATCH_TIME_FOREVER)

#define TFY_MessageMUnLock() dispatch_semaphore_signal(MessageMSemaphore)

@interface TFY_MessageM (){
@private
    NSMutableDictionary *messageListeners;
    dispatch_semaphore_t MessageMSemaphore;
}
@end

@implementation TFY_MessageM
#pragma mark - =========================初始化=========================
/**
 单例消息中心
 */
+ (instancetype)message{
    static id sharedMessageM;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMessageM = [[self alloc] init];
    });
    return sharedMessageM;
}

- (instancetype)init{
    self = [super init];
    if (self) {
        messageListeners = [NSMutableDictionary dictionary];
        MessageMSemaphore = dispatch_semaphore_create(1);
    }
    return self;
}


#pragma mark - =========================Public Methods=========================
/**
 添加消息接收者
 消息接收者
 message 消息
 selector 执行方法，【@selector(method:)参数为消息内容，参数可以省略】
 */
- (void)addListener:(id)listener forMessage:(NSString *)message selector:(SEL)selector;{
    TFY_MessageMLock();
    NSMapTable *listerMap = [messageListeners objectForKey:message];
    if (!listerMap) {
        listerMap = [NSMapTable mapTableWithKeyOptions:NSMapTableWeakMemory
                                          valueOptions:NSMapTableCopyIn];
    }
    [listerMap setObject:NSStringFromSelector(selector) forKey:listener];
    
    [messageListeners setObject:listerMap
                         forKey:message];
    TFY_MessageMUnLock();
}

/**
 添加消息接收者
 listener 消息接收者
 message 消息
 block 执行回调
 */
- (void)addListener:(id)listener forMessage:(NSString *)message usingBlock:(nullable MessageMCompletionBlock)block;{
    TFY_MessageMLock();
    NSMapTable *listerMap = [messageListeners objectForKey:message];
    if (!listerMap) {
        listerMap = [NSMapTable mapTableWithKeyOptions:NSMapTableWeakMemory
                                          valueOptions:NSMapTableCopyIn];
    }
    [listerMap setObject:block forKey:listener];
    
    [messageListeners setObject:listerMap
                         forKey:message];
    TFY_MessageMUnLock();
}

/**
 移除消息接收者
 listener 消息接收者
 message 消息
 */
- (void)removeListener:(id)listener forMessage:(NSString *)message;{
    TFY_MessageMLock();
    NSMapTable *listerMap = [messageListeners objectForKey:message];
    if (listerMap) {
        [listerMap removeObjectForKey:listener];
        if ([listerMap count]) {
            [messageListeners setObject:listerMap
                                 forKey:message];
        }else{
            [messageListeners removeObjectForKey:message];
        }
    }
    TFY_MessageMUnLock();
    
}

/**
 发送消息
 message 消息
 object 消息发送内容
 */
- (void)sendMessage:(NSString *)message object:(nullable id)object;{
    [self sendMessage:message object:object userInfo:nil];
}


/**
 发送消息
 message 消息
 object 消息发送内容
 userInfo 附属内容
 */
- (void)sendMessage:(NSString *)message object:(nullable id)object userInfo:(nullable NSDictionary *)userInfo;{
    dispatch_queue_t sendMessageQueue = dispatch_queue_create("com.message.TFY-MessageMKit.sendMessageQueue", DISPATCH_QUEUE_CONCURRENT);
    dispatch_async(sendMessageQueue, ^{
        
        dispatch_semaphore_wait(self->MessageMSemaphore, DISPATCH_TIME_FOREVER);
        
        NSMapTable *listerMap = [self->messageListeners objectForKey:message];
        TFY_MessageData *messageData = [TFY_MessageData messageWithName:message object:object userInfo:userInfo];
        if ([listerMap count]) {
            
            for (id listener in listerMap) {
                id listenEventValue = [listerMap objectForKey:listener];
                /** 代表存的为Selector */
                if ([listenEventValue isKindOfClass:[NSString class]]) {
                    SEL aSelector = NSSelectorFromString(listenEventValue);
                    if ([listener respondsToSelector:aSelector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored"-Warc-performSelector-leaks"
                        if ([((NSString *)listenEventValue) containsString:@":"]) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [listener performSelector:aSelector withObject:messageData];
                            });
                        }else{
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [listener performSelector:aSelector];
                            });
                            
                        }
#pragma clang diagnostic pop
                    }
                    continue;
                }
                /** 否则为Block */
                MessageMCompletionBlock block = listenEventValue;
                if (block) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        block(messageData);
                    });
                }
            }
        }
        dispatch_semaphore_signal(self->MessageMSemaphore);
    });
}


@end

@implementation TFY_MessageData

- (instancetype)initWithName:(NSString *)name object:(id)object userInfo:(NSDictionary *)userInfo {
    self = [super init];
    if (self) {
        _name = name;
        _object = object;
        _userInfo = userInfo;
    }
    return self;
}

+ (instancetype)messageWithName:(NSString *)name object:(id)object userInfo:(NSDictionary *)userInfo{
    return [[self alloc] initWithName:name object:object userInfo:userInfo];
}

+ (instancetype)messageWithName:(NSString *)name object:(id)object{
    return [self messageWithName:name object:object userInfo:nil];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"\n{\n\tMessage:%p \n\tName:\"%@\" \n\tObject:%@ \n\tUserInfo:%@\n}", self ,
            _name ? : @"<nil>",
            _object ? : @"<nil>",
            _userInfo ? : @"<nil>"];
}
@end
