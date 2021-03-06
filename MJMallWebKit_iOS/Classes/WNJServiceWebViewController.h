//
//  WNJServiceWebViewController.h
//  WisdomNujiangIOS
//
//  Created by 陈诚 on 2020/3/30.
//  Copyright © 2020 陈诚. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN



@interface WNJServiceWebViewController : UIViewController

@property (nonatomic, strong, readonly) WKWebView *webView;

/// 页面url
@property (nonatomic, copy) NSString *url;


@end

NS_ASSUME_NONNULL_END
