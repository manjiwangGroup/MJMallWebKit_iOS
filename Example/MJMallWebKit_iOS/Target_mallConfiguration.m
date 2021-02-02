//
//  Target_mallConfiguration.m
//  MJMallWebKit_iOS_Example
//
//  Created by manjiwang on 2021/2/2.
//  Copyright © 2021 jgyhc. All rights reserved.
//

#import "Target_mallConfiguration.h"

@implementation Target_mallConfiguration

- (id)Action_webCookie:(NSDictionary *)params {
    
    return @{
        @"sessionId":@"目前的用户登录凭证(后续会废弃，采用access_token)",
        @"openId":@"支付平台申请的openId",
        @"appId":@"支付平台申请的appId",
        @"isRealNameAuth":@"是否实名认证",
        @"Authorization":@"access_token",
        @"refreshToken":@"刷新token",
        @"browseType":@"WisdomNuJiang"
    };
}

- (id)Action_easyshare:(NSDictionary *)params {
    return nil;
}

- (id)Action_manjiwangshare:(NSDictionary *)params {
    return nil;
}

//登录成功通知key
- (id)Action_loginOutNotifyKey:(NSDictionary *)params {
    return @"wnjLoginOutNotify";
}

//退出登录通知key
- (id)Action_loginNotifyKey:(NSDictionary *)params {
    return @"dissmissLoginViewNotify";
}



@end
