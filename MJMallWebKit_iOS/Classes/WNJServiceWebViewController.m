//
//  WNJServiceWebViewController.m
//  WisdomNujiangIOS
//
//  Created by 陈诚 on 2020/3/30.
//  Copyright © 2020 陈诚. All rights reserved.
//

#import "WNJServiceWebViewController.h"
#import <Masonry/Masonry.h>
#import <CTMediator/CTMediator.h>


// WKWebView 内存不释放的问题解决
@interface WeakWebViewScriptMessageDelegate : NSObject <WKScriptMessageHandler>

//WKScriptMessageHandler 这个协议类专门用来处理JavaScript调用原生OC的方法
@property (nonatomic, weak) id <WKScriptMessageHandler> scriptDelegate;

- (instancetype)initWithDelegate:(id<WKScriptMessageHandler>)scriptDelegate;

@end

@implementation WeakWebViewScriptMessageDelegate

- (instancetype)initWithDelegate:(id<WKScriptMessageHandler>)scriptDelegate {
    if (self = [super init]) {
        _scriptDelegate = scriptDelegate;
    }
    return self;
}

#pragma mark - WKScriptMessageHandler
//遵循WKScriptMessageHandler协议，必须实现如下方法，然后把方法向外传递
//通过接收JS传出消息的name进行捕捉的回调方法
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([self.scriptDelegate respondsToSelector:@selector(userContentController:didReceiveScriptMessage:)]) {
        [self.scriptDelegate userContentController:userContentController didReceiveScriptMessage:message];
    }
}

@end


static NSString* const kJavaScriptMethodName = @"Native";
static NSString* const kJavaScriptOpertion = @"action";
@interface WNJServiceWebViewController () <WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler>

@property (nonatomic, strong, readwrite) WKWebView *webView;

@property (nonatomic, strong) UIProgressView *progressView;

@property (nonatomic, strong) UIView *statusBar;

@property (nonatomic, strong) WKWebViewConfiguration *configuration;

@property (nonatomic, assign) NSInteger pageCount;

@end

@implementation WNJServiceWebViewController

#pragma mark - 全能初始化方法
- (instancetype)initWithUrl:(NSString *)url withTitle:(NSString *)title {
    if (self = [super init]) {
        _url = url;
        _titleName = title;
    }
    return self;
}

static inline CGFloat mj_statusBarHeight() {
    CGRect statusBarFrame = [[UIApplication sharedApplication] statusBarFrame];
    return statusBarFrame.size.height;
}

static inline CGFloat mj_bottomSpace() {
    if (@available(iOS 11.0, *)) {
        UIWindow *keyWindow = [[[UIApplication sharedApplication] delegate] window];
        // 获取底部安全区域高度，iPhone X 竖屏下为 34.0，横屏下为 21.0，其他类型设备都为 0
        CGFloat bottomSafeInset = keyWindow.safeAreaInsets.bottom;
        return bottomSafeInset;
    }
    return 0;
}

#pragma mark - Ctl生命周期
- (void)dealloc {
    //移除KVO观察者
    [self.webView removeObserver:self forKeyPath:@"title"];
    [self.webView removeObserver:self forKeyPath:@"estimatedProgress"];
    //移除微信支付回调通知
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"NJPayWeChatPayResultNotificationKey" object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view addSubview:self.statusBar];
    [self.statusBar mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.mas_equalTo(self.view);
        make.height.mas_equalTo(_isHiddenNav?mj_statusBarHeight():0);
    }];
    
    [self.view addSubview:self.webView];
    [self.webView mas_makeConstraints:^(MASConstraintMaker *make) {
        if ([_url containsString:@"lustreMall"]) {//附近光彩商城相关页面底部要在Tabbar上面
            make.left.right.mas_equalTo(self.view);
            make.top.mas_equalTo(self.statusBar.mas_bottom);
            make.bottom.mas_equalTo(self.view).offset(-49-mj_bottomSpace());
        }else {
            make.top.mas_equalTo(self.statusBar.mas_bottom);
            make.left.right.bottom.mas_equalTo(self.view);
        }
    }];
    
    [self.view addSubview:self.progressView];
    [self.progressView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.mas_equalTo(self.view);
        make.top.mas_equalTo(self.statusBar.mas_bottom);
    }];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:_url]];
    [request addValue:@"http://uipay.manjiwang.com/" forHTTPHeaderField:@"referer"];
    [self.webView loadRequest:request];

    //添加KVO监听title
    [self.webView addObserver:self forKeyPath:@"title" options:NSKeyValueObservingOptionNew context:NULL];
    //添加KVO监听网页加载进度
    [self.webView addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:NULL];
    //微信回调通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(weChatPayReslut:) name:@"NJPayWeChatPayResultNotificationKey" object:nil];
    //登录成功通知
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loginSuccessNotify:) name:[[CTMediator sharedInstance] performTarget:@"mallConfiguration" action:@"loginNotifyKey" params:nil shouldCacheTarget:YES] object:nil];
    //退出登录成功通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(wnjLoginOutNotify:) name:[[CTMediator sharedInstance] performTarget:@"mallConfiguration" action:@"loginOutNotifyKey" params:nil shouldCacheTarget:YES] object:nil];
}

- (void)weChatPayReslut:(NSNotification *)notifition {
    if ([self.url containsString:@"uipay.manjiwang.com"]) {
        [self.webView evaluateJavaScript:@"getPayOrderStatus()" completionHandler:^(id _Nullable object, NSError * _Nullable error) {
            NSLog(@" - %@ -- %@ --- ",error,object);
        }];
    }else if ([self.url containsString:@"wap.manjiwang.com"]) {
        [self.webView evaluateJavaScript:@"getPayOrderStatus()" completionHandler:^(id _Nullable object, NSError * _Nullable error) {
            NSLog(@" - %@ -- %@ --- ",error,object);
        }];
    }
}

- (void)loginSuccessNotify:(NSNotification *)nofification {
    //登录成功,重新获取cookie，并刷新当前webView
    [self updateUserInfoWithConfig:_configuration];
    //调用js方法，js那边去刷新cookie
    [self.webView evaluateJavaScript:@"refreshCookie()" completionHandler:nil];

    __weak typeof(self)wself = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [wself.webView reload];
    });
}

- (void)wnjLoginOutNotify:(NSDictionary *)notification {
    __weak typeof(self)wself = self;
    //退出登录,清除缓存
    //WKWebsiteDataStore这个类暴露了一些获取（清除）特定缓存的能力，这里包括了cookie
    //fetchDataRecordsOfTypes方法用于获取某些指定的数据类型，最后数据实例用一个统一的抽象的WKWebsiteDataRecord来表示
    [[WKWebsiteDataStore defaultDataStore] fetchDataRecordsOfTypes:[NSSet setWithObjects:WKWebsiteDataTypeCookies, nil] completionHandler:^(NSArray<WKWebsiteDataRecord *> * _Nonnull records) {
            //removeDataOfTypes移除指定时期的特定的数据类型
             [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:[WKWebsiteDataStore allWebsiteDataTypes] forDataRecords:records completionHandler:^{
                 [wself.configuration.userContentController removeAllUserScripts];
                 [wself.webView reload];
            }];
    }];
}

/// MARK: kVO监听方法
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"title"]) {
        if (_titleName && ![_titleName isEqualToString:@""]) {
            self.title = _titleName;
        }else {
            self.title = self.webView.title;
        }
    }else if ([keyPath isEqualToString:@"estimatedProgress"]) {
        [self.progressView setAlpha:1.0f];
        BOOL animated = self.webView.estimatedProgress > self.progressView.progress;
        [self.progressView setProgress:self.webView.estimatedProgress animated:animated];
        if (self.webView.estimatedProgress >= 1.0f) {
            __weak typeof(self)wself = self;
            [UIView animateWithDuration:0.3f delay:0.3f options:UIViewAnimationOptionCurveEaseOut animations:^{
                [wself.progressView setAlpha:0.0f];
            } completion:^(BOOL finished) {
                [wself.progressView setProgress:0.0f animated:NO];
            }];
        }
    }else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

/// MARK: 重写分类UIViewController+NavigationBarSetting中的onBack(点击返回按钮)方法
- (void)onBack {
    if ([self.navigationController.viewControllers count] > 1) {
        if (self.webView.canGoBack) {
            [self.webView goBack];
        }else{
            [self.navigationController popViewControllerAnimated:YES];
        }
    }
}

#pragma mark - setMethod
- (void)setIsHiddenNav:(BOOL)isHiddenNav {
    _isHiddenNav = isHiddenNav;
}

#pragma mark - WKScriptMessageHandler
/// 被自定义的WKScriptMessageHandler在回调方法里通过代理回调回来，绕了一圈就是为了解决内存不释放的问题
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([message.name isEqualToString:kJavaScriptMethodName]) {
        NSDictionary *dic;
        if ([message.body isKindOfClass:[NSDictionary class]]) {
            dic = message.body;
        }else {
            dic = [self dictionaryWithJsonString:message.body];
        }
        if (!dic) {
            return;
        }
        
        id dataObj = [dic objectForKey:@"data"];
        NSString *action = [dic objectForKey:@"action"];
        if ([action isEqualToString:@"back"]) {
            [self back:nil];
            return;
        }
        if ([action isEqualToString:@"close"]) {
            [self handleCloseAction:nil];
            return;
        }
        
        if ([action isEqualToString:@"general_links"] || [action isEqualToString:@"login"] || [action isEqualToString:@"token_expired"] || [action isEqualToString:@"recharge_success"] || [action isEqualToString:@"recharge_failure"]) {
            if ([message.webView.title isEqualToString:@"邀请奖励"]) {
                [self viewWillBack];
                return;
            }
            NSDictionary *data = dataObj;
            if ([data isKindOfClass:[NSDictionary class]]) {
                NSString *url = [data objectForKey:@"url"];
                [[CTMediator sharedInstance] performActionWithUrl:[NSURL URLWithString:url] completion:nil];
            }else if ([data isKindOfClass:[NSString class]]) {
                NSString *url = dataObj;
                [[CTMediator sharedInstance] performActionWithUrl:[NSURL URLWithString:url] completion:nil];
            }
        }

        if ([action isEqualToString:@"webview_links"]) {
            if ([dataObj isKindOfClass:[NSDictionary class]]) {
                NSDictionary *data = dataObj;
                NSString *url = [data objectForKey:@"url"];
                WNJServiceWebViewController *webView = [[WNJServiceWebViewController alloc] initWithUrl:url withTitle:@"" isHiddenNav:NO];
                [self.navigationController pushViewController:webView animated:YES];
            }else if ([dataObj isKindOfClass:[NSString class]]) {
                NSString *url = dataObj;
                WNJServiceWebViewController *webView = [[WNJServiceWebViewController alloc] initWithUrl:url withTitle:@"" isHiddenNav:NO];
                [self.navigationController pushViewController:webView animated:YES];
            }
        }

        if ([action isEqualToString:@"navigation_bar_style"]) {
            NSDictionary *data = dataObj;
            NSString *statuBarColor = [data objectForKey:@"navigationBackgroundColor"];
            NSString *statuBarStyle = [data objectForKey:@"statusBarStyle"];
            self.statusBar.backgroundColor = [self colorWithHexString:statuBarColor];
            if ([statuBarStyle isEqualToString:@"light"]) {
                [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
            }else {
                [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault];
            }
        }
        if ([action isEqualToString:@"easyshare"]) {
            NSDictionary *data = dataObj;
            [[CTMediator sharedInstance] performTarget:@"mallConfiguration" action:@"easyshare" params:data shouldCacheTarget:NO];
        }
        if ([action isEqualToString:@"manjiwangshare"]) {
            NSDictionary *data = dataObj;
            //光彩云商品详情右上角调起本地分享
            [[CTMediator sharedInstance] performTarget:@"mallConfiguration" action:@"manjiwangshare" params:data shouldCacheTarget:NO];
        }
    }
}

- (void)back:(NSDictionary *)dic {
    [self viewWillBack];
}

- (void)handleCloseAction:(id)sender {
    if (self.presentingViewController) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }else{
        [self.navigationController popViewControllerAnimated:YES];
    }
}

#pragma mark - WKNavigationDelegate (ps:WKNavigationDelegate主要处理一些跳转、加载处理操作)
/// MARK: 根据WebView对于即将跳转的HTTP请求头信息和相关信息来决定是否跳转
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSString* reqUrl = navigationAction.request.URL.absoluteString;
    if ([reqUrl hasPrefix:@"weixin://"]) {
        [[UIApplication sharedApplication]openURL:navigationAction.request.URL];
    }
    decisionHandler(WKNavigationActionPolicyAllow);
}

/// MARK: 根据客户端受到的服务器响应头以及response相关信息来决定是否可以跳转
- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler{
    NSString * urlStr = navigationResponse.response.URL.absoluteString;
    NSLog(@"当前跳转地址：%@",urlStr);
    //允许跳转
    decisionHandler(WKNavigationResponsePolicyAllow);
    //不允许跳转
    //decisionHandler(WKNavigationResponsePolicyCancel);
}

/// MARK:需要响应身份验证时调用 - 在block中需要传入用户身份凭证
- (void)webView:(WKWebView *)webView didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler {
    //WKWebView信任Https请求
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        NSURLCredential *card = [[NSURLCredential alloc]initWithTrust:challenge.protectionSpace.serverTrust];
        completionHandler(NSURLSessionAuthChallengeUseCredential,card);
    }
}

#pragma mark - WKUIDelegate (ps:主要处理JS脚本，确认框，警告框等)
/// web界面中有弹出警告框时调用
/// @param webView 实现该代理的webview
/// @param message 警告框中的内容
/// @param completionHandler 警告框消失调用
- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler {
    
}

/// web界面中有弹出确认框时调用(需要在block中把用户选择的情况传递进去)
/// @param webView 实现该代理的webview
/// @param message 警告框中的内容
/// @param completionHandler 警告框消失调用
- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL))completionHandler {
    
}

/// web界面中有弹出警告框时调用(需要在block中把用户输入的信息传递进去)
/// @param webView 实现该代理的webview
/// @param prompt js中的输入框
/// @param defaultText 默认Text
/// @param completionHandler 警告框消失调用
- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString * _Nullable))completionHandler {
    
}

#pragma mark - private
- (void)updateUserInfoWithConfig:(WKWebViewConfiguration *)config {
    NSDictionary *params = [[CTMediator sharedInstance] performTarget:@"mallConfiguration" action:@"webCookie" params:nil shouldCacheTarget:YES];
    
    // 将所有cookie以document.cookie = 'key=value';形式进行拼接
    NSMutableString *cookie = @"".mutableCopy;

    if (params) {
        for (NSString *key in params.allKeys) {
            [cookie appendFormat:@"document.cookie = '%@=%@';\n", key, params[key]];
        }
    }
    WKUserScript *cookieScript = [[WKUserScript alloc] initWithSource:cookie injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
    [config.userContentController addUserScript:cookieScript];
}

- (NSDictionary *)dictionaryWithJsonString:(NSString *)jsonString {
    if (jsonString == nil) {
        return nil;
    }

    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *err;
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:jsonData
                                                        options:NSJSONReadingMutableContainers
                                                          error:&err];
    if(err) {
        NSLog(@"json解析失败：%@",err);
        return nil;
    }
    return dic;
}


- (UIColor *)colorWithHexString:(NSString *)stringToConvert{
    return [self colorWithHexString:stringToConvert alpha:1];
}

- (UIColor *)colorWithHexString:(NSString *)stringToConvert alpha:(CGFloat)alpha
{
    if (alpha < 0) {
        alpha = 0;
    }else if (alpha > 1){
        alpha = 1;
    }
    NSString *cString = [[stringToConvert stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
    
    // String should be 6 or 8 characters
    if ([cString length] < 6) {
        return [UIColor clearColor];
    }
    
    // strip 0X if it appears
    if ([cString hasPrefix:@"0X"])
        cString = [cString substringFromIndex:2];
    if ([cString hasPrefix:@"#"])
        cString = [cString substringFromIndex:1];
    if ([cString length] != 6)
        return [UIColor clearColor];
    
    NSScanner *scanner = [NSScanner scannerWithString:cString];
    unsigned hexNum;
    if (![scanner scanHexInt:&hexNum]) return nil;
    return [self colorWithRGBHex:hexNum alpha:alpha];
}

- (UIColor *)colorWithRGBHex:(UInt32)hex  alpha:(CGFloat)alpha
{
    if (alpha < 0) {
        alpha = 0;
    }else if (alpha > 1){
        alpha = 1;
    }
    int r = (hex >> 16) & 0xFF;
    int g = (hex >> 8) & 0xFF;
    int b = (hex) & 0xFF;
    
    return [UIColor colorWithRed:r / 255.0f
                           green:g / 255.0f
                            blue:b / 255.0f
                           alpha:alpha];
}


- (void)viewWillBack {
    if (self.webView.canGoBack) {
        [self.webView goBack];
    }else{
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (WKWebView *)webView {
    if (!_webView) {
        /// 1.初始化网页配置对象
        _configuration = [[WKWebViewConfiguration alloc] init];
        
        //自定义的WKScriptMessageHandler 是为了解决内存不释放的问题
        WeakWebViewScriptMessageDelegate *weakScriptMessageDelegate = [[WeakWebViewScriptMessageDelegate alloc] initWithDelegate:self];
        /// 2.WKUserContentController这个类主要用来做native与JavaScript的交互管理
        WKUserContentController *wkUController = [[WKUserContentController alloc] init];
//        [wkUController addScriptMessageHandler:self name:kJavaScriptMethodName];//直接这样写会内存泄漏！
        [wkUController addScriptMessageHandler:weakScriptMessageDelegate name:kJavaScriptMethodName];
        _configuration.userContentController = wkUController;
        
        /// 3.WKPreferences这个类主要设置偏好
        WKPreferences *preference = [[WKPreferences alloc] init];
        // 默认认为YES
        preference.javaScriptEnabled = YES;
        // 在iOS上默认为NO，表示不能自动通过窗口打开
        preference.javaScriptCanOpenWindowsAutomatically = YES;
        _configuration.preferences = preference;
        
        /// 4.配置cookies
        [self updateUserInfoWithConfig:_configuration];
        
        /// 5.初始化wkwebview
        _webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:_configuration];
        _webView.allowsBackForwardNavigationGestures = YES;
        _webView.UIDelegate = self;
        _webView.navigationDelegate = self;
        [_webView setAllowsBackForwardNavigationGestures:YES];
    }
    return _webView;
}

- (UIView *)statusBar {
    if (!_statusBar) {
        _statusBar = [UIView new];
    }
    return _statusBar;
}

- (UIProgressView *)progressView {
    if (!_progressView) {
        _progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        [_progressView setTrackTintColor:[UIColor colorWithWhite:1.0f alpha:0.0f]];
        [_progressView setTintColor:[self colorWithHexString:@"#4ec7ef"]];
    }
    return _progressView;
}
@end
