//
//  WhalePayViewController.m
//  WhalePaySDK
//
//  Created by 李勇 on 2017/3/2.
//  Copyright © 2017年 liyong. All rights reserved.
//

#import "WhalePayViewController.h"

#import "NSDate+WhaleHelper.h"
#import "NSString+WhaleHelper.h"
#import "MBProgressHUD.h"
#import "ControllerActivity.h"
#import "DataSigner.h"
#import "DataVerifier.h"
#import "Base64Data.h"
#import "SecKeyWrapper.h"
#import "RSAUtil.h"
#import "WhalePayWayCell.h"
#import "UIImageView+WhaleHelper.h"

//微信
#import "WXApi.h"
//支付宝
#import <AlipaySDK/AlipaySDK.h>

/**
 SDK与金融平台的交互流程：
 1、使用金融平台的appkey请求鉴权微服务，获取token
 2、使用token请求/account/listAccountType接口获取接入商支持的收费通道
 3、使用token请求/transaction/prepay接口创建预付单
 */

#define AuthUrl @"http://neotest.kakatool.cn:8098/app/auth"//鉴权微服务 POST
#define PayWayUrl @"http://neotest.kakatool.cn:8097/account/listAccountType?access_token="//接口获取接入商支持的收费通道 POST
#define kUrl @"http://neotest.kakatool.cn:8097/transaction/prepay" // 创建预支付订单的地址，金融平台地址
#define PrePayUrl @"http://neotest.kakatool.cn:8097/transaction/prepay?access_token="//预支付订单



@implementation WPOrder

@end



@implementation WPReceiptType

@end


@interface WhalePayViewController ()<UITableViewDelegate,UITableViewDataSource,WXApiDelegate>

@property (strong, nonatomic) WPOrder *wpOrder;//
@property (strong, nonatomic) NSDictionary *payWay;//选择的支付通道
@property (strong, nonatomic) NSMutableArray *payWayList;//支付方式
@property (copy, nonatomic) NSString *access_token;//鉴权token
@property (copy, nonatomic) NSString *expire;//过期时间

@property (nonatomic, copy) NSString *appkey;//接入应用新增成功后，系统将自动生成20位的appkey和32位的appsercet
@property (nonatomic, copy) NSString *appsecret;//接入应用新增成功后，系统将自动生成20位的appkey和32位的appsercet
@property (copy, nonatomic) NSString *wxAppid;//微信支付appid
@property (copy, nonatomic) NSString *aliSchemel;//ali支付schemel


@property (copy, nonatomic) AKPayCompletion akCompletionBlock;

@property (strong, nonatomic) NSDictionary *payResult;//支付结果

@property (strong, nonatomic) WPReceiptType *defaultReceiptType;//默认的收款通道

@property (nonatomic, strong) NSIndexPath *selectedIndex;//选中的支付索引

@property (strong, nonatomic) UITableView *tableView;//
@property (strong, nonatomic) UIButton *payBtn;//支付按钮
@end


@implementation WhalePayViewController

//单例
@def_singleton(WhalePayViewController);

- (NSMutableArray *)payWayList{
    if (!_payWayList){
        _payWayList = [NSMutableArray array];
    }
    return _payWayList;
}

- (UITableView *)tableView{
    if (!_tableView){
        _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, SCRREN_WIDTH, SCRREN_HEIGHT - 50) style:UITableViewStylePlain];
    }
    return _tableView;
}

- (UIButton *)payBtn{
    if (!_payBtn){
        _payBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, SCRREN_HEIGHT - 50, SCRREN_WIDTH, 50)];
        [_payBtn setTitle:@"立即支付" forState:UIControlStateNormal];
        _payBtn.backgroundColor = RGBCOLOR(33, 143, 230);
        [_payBtn setTintColor:[UIColor whiteColor]];
        
        [_payBtn addTarget:self action:@selector(getPreparePayOrderPayWay) forControlEvents:UIControlEventTouchUpInside];
        
        [self.view addSubview:_payBtn];
    }
    return _payBtn;
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    
    self.selectedIndex = [NSIndexPath indexPathForRow:0 inSection:0];
    //制造空页面
    [self.payWayList removeAllObjects];
    [self.tableView reloadData];
    self.tableView.tableHeaderView = nil;
    self.payBtn.hidden = YES;
    
    //默认title
    if (![self.navigationItem.title isNotNull]){
        self.navigationItem.title = @"支付";
    }
    
    if (![self.bundleName isNotNull]){
        self.bundleName = @"WhaleResources";
    }
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.tableView.backgroundColor = RGBCOLOR(240, 240, 240);
    self.view.backgroundColor = RGBCOLOR(240, 240, 240);
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.tableView registerNib:[UINib nibWithNibName:@"WhalePayWayCell" bundle:nil] forCellReuseIdentifier:@"WhalePayWayCell"];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
    
    
    //返回按钮
    NSString * path = [[NSBundle mainBundle] pathForResource:self.bundleName ofType:@"bundle"];
    UIImage *backImg = [UIImage imageWithContentsOfFile:[path stringByAppendingPathComponent:@"arrow.png"]];
    UIButton *backBtn = [[UIButton alloc] initWithFrame:CGRectMake(15, 25, 10, 15)];
    [backBtn setImage:backImg forState:UIControlStateNormal];
    [backBtn addTarget:self action:@selector(dealPayResult) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:backBtn];
    
    
}
#pragma mark - 设置页面布局
- (void)setupTableHeadViewWithName:(NSString *)name Money:(NSString *)money Content:(NSString *)content{
    
    UIView *tableheadView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, SCRREN_WIDTH, 160)];
    tableheadView.backgroundColor = RGBCOLOR(240, 240, 240);
    
    UIView *subView = [[UIView alloc] initWithFrame:CGRectMake(0, 10, SCRREN_WIDTH, 140)];
    subView.backgroundColor = [UIColor whiteColor];
    [tableheadView addSubview:subView];
    
    //待支付金额
    UILabel *lbl1 = [[UILabel alloc] initWithFrame:CGRectMake(0, 10, SCRREN_WIDTH, 21)];
    lbl1.text = @"待支付金额";
    lbl1.textAlignment = NSTextAlignmentCenter;
    lbl1.textColor = RGBCOLOR(33, 33, 33);
    lbl1.font = [UIFont systemFontOfSize:14.0];
    [subView addSubview:lbl1];
    
    //支付金额
    UILabel *lbl2 = [[UILabel alloc] initWithFrame:CGRectMake(0, 35, SCRREN_WIDTH, 40)];
    lbl2.text = [NSString stringWithFormat:@"%@元",money];
    lbl2.textAlignment = NSTextAlignmentCenter;
    lbl2.textColor = [UIColor blackColor];
    lbl2.font = [UIFont systemFontOfSize:30.0];
    [subView addSubview:lbl2];
    
    //支付类型标题
    UILabel *lbl3 = [[UILabel alloc] initWithFrame:CGRectMake(10, 90, 80, 21)];
    lbl3.text = @"支付类型";
    lbl3.textAlignment = NSTextAlignmentLeft;
    lbl3.textColor = RGBCOLOR(183, 183, 183);
    lbl3.font = [UIFont systemFontOfSize:14.0];
    [subView addSubview:lbl3];
    
    //支付类型内容
    UILabel *lbl4 = [[UILabel alloc] initWithFrame:CGRectMake(100, 90, SCRREN_WIDTH - 110, 21)];
    lbl4.text = [NSString stringWithFormat:@"%@",name];
    lbl4.textAlignment = NSTextAlignmentRight;
    lbl4.textColor = RGBCOLOR(183, 183, 183);
    lbl4.font = [UIFont systemFontOfSize:14.0];
    [subView addSubview:lbl4];
    
    
    //产品信息标题
    UILabel *lbl5 = [[UILabel alloc] initWithFrame:CGRectMake(10, 110, 80, 21)];
    lbl5.text = @"产品信息";
    lbl5.textAlignment = NSTextAlignmentLeft;
    lbl5.textColor = RGBCOLOR(183, 183, 183);
    lbl5.font = [UIFont systemFontOfSize:14.0];
    [subView addSubview:lbl5];
    
    //产品信息内容
    UILabel *lbl6 = [[UILabel alloc] initWithFrame:CGRectMake(100, 110, SCRREN_WIDTH - 110, 21)];
    lbl6.text = self.wpOrder.content;
    lbl6.textAlignment = NSTextAlignmentRight;
    lbl6.textColor = RGBCOLOR(183, 183, 183);
    lbl6.font = [UIFont systemFontOfSize:14.0];
    [subView addSubview:lbl6];
    
    self.tableView.tableHeaderView = tableheadView;
    
}


#pragma mark - 返回支付结果
- (void)dealPayResult{
    if (self.payResult == nil || self.payResult.allKeys.count == 0){
        self.payResult = @{
                           @"code" : @"1000",
                           @"message" : @"客户取消操作"
                           };
    }
    
    self.akCompletionBlock(self.payResult);
    
    [self.navigationController popViewControllerAnimated:YES];
}



/**
 支付调用接口(支付宝/微信)
 
 @param wpOrder wpOrder 对象(JSON 格式字符串 或 NSDictionary)
 @param viewController 当前控制器，做跳转用
 @param completion 支付结果回调 Block
 */
- (void)createPayment:(WPOrder *)wpOrder viewController:(UIViewController *)viewController withCompletion:(AKPayCompletion)completion{
    
    //1.检测是否注册成功
    if ([self.appkey isNotNull] && [self.appsecret isNotNull]){
        //2.检测必要条件
        if ([self checkRequireParams:wpOrder]){
            //3.跳转页面
            [viewController.navigationController pushViewController:self animated:YES];
            //4.鉴权
            if ([self isLocalTokenCanUse]){
                //获取支付方式
                [self getPayWay:self.wpOrder];
            }else{
                //重新鉴权并获取支付方式
                [self getToken:wpOrder from:1];
            }
            //5.保存回调代码
            self.akCompletionBlock = completion;
        }else{
            [MBProgressHUD showMessage:@"请补全必要参数" toView:viewController.view];
        }
    }else{
        [MBProgressHUD showMessage:@"注册ID失败" toView:viewController.view];
    }
}

//1.检测必要条件
- (BOOL)checkRequireParams:(WPOrder *)wpOrder{
    if ([wpOrder.pno isNotNull] && [wpOrder.cno isNotNull] && [wpOrder.orderno isNotNull] && [wpOrder.content isNotNull] && [wpOrder.userId isNotNull]){
        
        //判断收款账号
        if (wpOrder.receiptArray.count == 0){
            return NO;
        }else{
            for (WPReceiptType *receiptType in wpOrder.receiptArray) {
                if ([receiptType.isDefault integerValue] == 1){
                    //保存默认信息
                    self.defaultReceiptType = receiptType;
                }
            }
        }
        
        //判断支持的支付通道
        if (wpOrder.payTypeArray.count == 0){
            return NO;
        }
        
        self.wpOrder = wpOrder;
        
        self.wpOrder.fixedorgmoney = wpOrder.fixedorgmoney ? wpOrder.fixedorgmoney : @"0";
        self.wpOrder.destsubaccount = wpOrder.destsubaccount ? wpOrder.destsubaccount : [NSDictionary dictionary];
        self.wpOrder.orgsubaccount = wpOrder.orgsubaccount ? wpOrder.orgsubaccount : [NSDictionary dictionary];
        self.wpOrder.detail = wpOrder.detail ? wpOrder.detail : @"";
        self.wpOrder.starttime = wpOrder.starttime ? wpOrder.starttime : @"";
        self.wpOrder.stoptime = wpOrder.stoptime ? wpOrder.stoptime : @"";
        self.wpOrder.callback = wpOrder.callback ? wpOrder.callback : @"";
        self.wpOrder.remoteip = wpOrder.remoteip ? wpOrder.remoteip : @"";
        self.wpOrder.mobile = wpOrder.mobile ? wpOrder.mobile : @"";
        self.wpOrder.userName = wpOrder.userName ? wpOrder.userName : @"";
        self.wpOrder.city = wpOrder.city ? wpOrder.city : @"";
        self.wpOrder.province = wpOrder.province ? wpOrder.province : @"";
        self.wpOrder.block = wpOrder.block ? wpOrder.block : @"";
        self.wpOrder.gbName = wpOrder.gbName ? wpOrder.gbName : @"";
        
        return YES;
    }
    return NO;
}

/**
 *  回调结果接口(支付宝/微信/测试模式)
 *
 *  @param url              结果url
 *  @param completion  支付结果回调 Block，保证跳转支付过程中，当 app 被 kill 掉时，能通过这个接口得到支付结果
 *
 *  @return                 当无法处理 URL 或者 URL 格式不正确时，会返回 NO。
 */
- (BOOL)handleOpenURL:(NSURL *)url withCompletion:(AKPayCompletion)completion{
    
    //如果极简开发包不可用，会跳转支付宝钱包进行支付，需要将支付宝钱包的支付结果回传给开发包
    if ([url.host isEqualToString:@"safepay"]) {
        [[AlipaySDK defaultService] processOrderWithPaymentResult:url standbyCallback:^(NSDictionary *resultDic) {
            //【由于在跳转支付宝客户端支付的过程中，商户app在后台很可能被系统kill了，所以pay接口的callback就会失效，请商户对standbyCallback返回的回调结果进行处理,就是在这个方法里面处理跟callback一样的逻辑】
            
            //处理支付结果
            [self aliPayResult:resultDic];
            NSLog(@"result = %@",resultDic);
        }];
        return YES;
    }
    if ([url.host isEqualToString:@"platformapi"]){//支付宝钱包快登授权返回authCode
        
        [[AlipaySDK defaultService] processAuthResult:url standbyCallback:^(NSDictionary *resultDic) {
            //【由于在跳转支付宝客户端支付的过程中，商户app在后台很可能被系统kill了，所以pay接口的callback就会失效，请商户对standbyCallback返回的回调结果进行处理,就是在这个方法里面处理跟callback一样的逻辑】
            NSLog(@"result = %@",resultDic);
            
            //处理支付结果
            [self aliPayResult:resultDic];
        }];
        return YES;
    }
    
    NSString *urlStr = [url absoluteString];
    if ([urlStr hasPrefix:self.wxAppid]){
        return [WXApi handleOpenURL:url delegate:self];
    }
    
    return YES;
}

/**
 *  回调结果接口(支付宝/微信/测试模式)
 *
 *  @param url                结果url
 *  @param sourceApplication  源应用 Bundle identifier
 *  @param completion    支付结果回调 Block，保证跳转支付过程中，当 app 被 kill 掉时，能通过这个接口得到支付结果
 *
 *  @return                   当无法处理 URL 或者 URL 格式不正确时，会返回 NO。
 */
- (BOOL)handleOpenURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication withCompletion:(AKPayCompletion)completion{
    
    //如果极简开发包不可用，会跳转支付宝钱包进行支付，需要将支付宝钱包的支付结果回传给开发包
    if ([url.host isEqualToString:@"safepay"]) {
        [[AlipaySDK defaultService] processOrderWithPaymentResult:url standbyCallback:^(NSDictionary *resultDic) {
            //【由于在跳转支付宝客户端支付的过程中，商户app在后台很可能被系统kill了，所以pay接口的callback就会失效，请商户对standbyCallback返回的回调结果进行处理,就是在这个方法里面处理跟callback一样的逻辑】
            NSLog(@"result = %@",resultDic);
            //处理支付结果
            [self aliPayResult:resultDic];
        }];
        return YES;
    }
    if ([url.host isEqualToString:@"platformapi"]){//支付宝钱包快登授权返回authCode
        
        [[AlipaySDK defaultService] processAuthResult:url standbyCallback:^(NSDictionary *resultDic) {
            //【由于在跳转支付宝客户端支付的过程中，商户app在后台很可能被系统kill了，所以pay接口的callback就会失效，请商户对standbyCallback返回的回调结果进行处理,就是在这个方法里面处理跟callback一样的逻辑】
            NSLog(@"result = %@",resultDic);
            //处理支付结果
            [self aliPayResult:resultDic];
        }];
        return YES;
    }
    
    NSString *urlStr = [url absoluteString];
    if ([urlStr hasPrefix:self.wxAppid]){
        return [WXApi handleOpenURL:url delegate:self];
    }
    
    return YES;
    
}

/**
 *  打开app时 注册APPID（微信）
 *
 *
 */
- (void)setAppId:(NSDictionary *)dict{
    self.wxAppid = [dict objectForKey:@"wxAppid"];
    self.appkey = [dict objectForKey:@"appkey"];
    self.appsecret = [dict objectForKey:@"appsecret"];
    self.aliSchemel = [dict objectForKey:@"aliSchemel"];
    
    //向微信注册
    [WXApi registerApp:self.wxAppid];
    
}

#pragma mark - 获取token
//from    1:支付通道   2:预支付订单
- (void)getToken:(WPOrder *)wpOrder from:(int)from{
    //加载等待......
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    
    //重新加载token
    NSURL* url = [NSURL URLWithString:AuthUrl];
    NSMutableURLRequest * postRequest = [NSMutableURLRequest requestWithURL:url];
    NSString *appkey = self.appkey;
    NSString *appsecret = self.appsecret;
    NSString *ts = [NSDate phpTimestamp];
    NSString *sign = [[NSString stringWithFormat:@"%@%@%@",appkey,ts,appsecret] MD5Hash];
    NSDictionary* dict = @{
                           @"appkey"  : appkey,
                           @"timestamp" : ts,
                           @"signature" : sign
                           };
    NSData* data = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:nil];
    NSString *bodyData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    [postRequest setHTTPBody:[NSData dataWithBytes:[bodyData UTF8String] length:strlen([bodyData UTF8String])]];
    [postRequest setHTTPMethod:@"POST"];
    [postRequest setValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:postRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
            if (httpResponse.statusCode == 2001) {
                NSLog(@"statusCode=%ld error = %@", (long)httpResponse.statusCode, connectionError);
                [MBProgressHUD showMessage:@"缺少key" toView:self.view];
                return;
            }
            if (httpResponse.statusCode == 2002) {
                NSLog(@"statusCode=%ld error = %@", (long)httpResponse.statusCode, connectionError);
                [MBProgressHUD showMessage:@"缺少时间戳" toView:self.view];
                return;
            }
            if (httpResponse.statusCode == 2003) {
                NSLog(@"statusCode=%ld error = %@", (long)httpResponse.statusCode, connectionError);
                [MBProgressHUD showMessage:@"无效的时间戳，时间戳与当前时间误差超过20分钟" toView:self.view];
                return;
            }
            if (httpResponse.statusCode == 2004) {
                NSLog(@"statusCode=%ld error = %@", (long)httpResponse.statusCode, connectionError);
                [MBProgressHUD showMessage:@"缺少签名" toView:self.view];
                return;
            }
            if (httpResponse.statusCode == 2005) {
                NSLog(@"statusCode=%ld error = %@", (long)httpResponse.statusCode, connectionError);
                [MBProgressHUD showMessage:@"验证失败，请确认appkey和appsecret" toView:self.view];
                return;
            }
            if (httpResponse.statusCode == 2006) {
                NSLog(@"statusCode=%ld error = %@", (long)httpResponse.statusCode, connectionError);
                [MBProgressHUD showMessage:@"应用不存在,请联系奥科管理员" toView:self.view];
                return;
            }
            if (connectionError != nil) {
                NSLog(@"error = %@", connectionError);
                [MBProgressHUD showMessage:[NSString stringWithFormat:@"%@",connectionError] toView:self.view];
                return;
            }
            
            NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
            NSLog(@"%@",result);
            if (result != nil && result.allKeys.count > 0){
                NSString *access_token = [[result objectForKey:@"content"] objectForKey:@"access_token"];
                NSString *expire = [[result objectForKey:@"content"] objectForKey:@"expire"];
                self.access_token = [NSString stringWithFormat:@"%@",access_token];
                self.expire = [NSString stringWithFormat:@"%@",expire];
                
                if (![self.access_token isNotNull] || ![self.expire isNotNull]){
                    [MBProgressHUD showMessage:@"鉴权失败，请重新尝试" toView:self.view];
                    NSLog(@"获取token失败");
                    [self.navigationController popViewControllerAnimated:YES];
                    return;
                }
                
                if (from == 1){
                    [self getPayWay:wpOrder];
                }else if (from == 2){
                    [self getPreparePayOrderPayWay];
                }
                
            }else{
                [MBProgressHUD showMessage:@"鉴权失败，请重新尝试" toView:self.view];
                [self.navigationController popViewControllerAnimated:YES];
            }
            
        });
    }];
}

//本地token的缓存是否可用
- (BOOL)isLocalTokenCanUse{
    if (![self.access_token isNotNull] || ![self.expire isNotNull]){
        return NO;
    }
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyyMMddHHmm"];
    [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:8*60*60]];//直接指定时区，这里是东8区
    NSString *date = [dateFormatter stringFromDate:[NSDate date]];
    NSString *expireDate = [NSDate longlongToDateTime:self.expire formator:@"yyyyMMddHHmm"];
    double preTime = [expireDate doubleValue] - [date doubleValue];
    
    if ([self.access_token isNotNull] && [self.expire isNotNull] && preTime > 5){
        return YES;
    }else{
        return NO;
    }
}

#pragma mark - 支付方式
- (void)getPayWay:(WPOrder *)wpOrder{
    //判断token是否失效
    if (![self isLocalTokenCanUse]){
        [self getToken:self.wpOrder from:2];
        return;
    }
    
    NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@",PayWayUrl,self.access_token]];
    NSMutableURLRequest * postRequest=[NSMutableURLRequest requestWithURL:url];
    NSDictionary* dict = @{
                           @"pno"  : wpOrder.pno,
                           @"cno" : wpOrder.cno
                           };
    NSData* data = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:nil];
    NSString *bodyData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    [postRequest setHTTPBody:[NSData dataWithBytes:[bodyData UTF8String] length:strlen([bodyData UTF8String])]];
    [postRequest setHTTPMethod:@"POST"];
    [postRequest setValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:postRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
            NSLog(@"%@",result);
            NSDictionary *content = [result objectForKey:@"content"];
            if (result.allKeys.count >0 && [[result objectForKey:@"code"] integerValue] == 0 && content.allKeys.count > 0){
                //加载成功
                [self.payWayList removeAllObjects];
                NSArray *list = [content objectForKey:@"list"];
                
                
                for (NSDictionary *dict in list) {
                    if ([[dict objectForKey:@"ctype"] integerValue] == 1){
                        //第三支付渠道
                        //默认收款为地方饭票
                        for (WPReceiptType *receipt in wpOrder.receiptArray) {
                            if ([[dict objectForKey:@"atid"] integerValue] == [receipt.atid integerValue]){
                                [self.payWayList addObject:dict];
                            }
                        }
                    }else if ([[dict objectForKey:@"ctype"] integerValue] == 4){
                        if (self.defaultReceiptType != nil && [self.defaultReceiptType.type isEqualToString:@"fanpiao"]){
                            //默认收款为全国饭票
                            for (NSNumber *atid in wpOrder.payTypeArray) {
                                if ([[dict objectForKey:@"atid"] integerValue] == [atid integerValue]){
                                    [self.payWayList addObject:dict];
                                }
                            }
                        }else{
                            //默认收款为地方饭票
                            for (WPReceiptType *receipt in wpOrder.receiptArray) {
                                if ([[dict objectForKey:@"atid"] integerValue] == [receipt.atid integerValue]){
                                    [self.payWayList addObject:dict];
                                }
                            }
                        }
                    }
                }
                
                
                
                if (self.payWayList.count > 1){
                    //支付方式列表
                    [self.tableView reloadData];
                    [MBProgressHUD hideHUDForView:self.view animated:YES];
                }else if (self.payWayList.count == 1){
                    //只有一种支付方式
                    self.payWay = [NSDictionary dictionaryWithDictionary:self.payWayList[0]];
                    //获取预支付订单
                    [self getPreparePayOrderPayWay];
                    
                }else{
                    //无支付方式可用
                    [MBProgressHUD showMessage:@"无支付方式可用,请联系奥科管理员" toView:self.view];
                    [self.navigationController popViewControllerAnimated:YES];
                }
            }else{
                //加载失败
                [MBProgressHUD showMessage:@"获取支付方式失败，请重新尝试" toView:self.view];
                [self.navigationController popViewControllerAnimated:YES];
            }
        });
    }];
}

#pragma mark - tableview
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    if (self.payWayList.count > 0){
        return self.payWayList.count;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    
    static NSString *cellID = @"WhalePayWayCell";
    
    WhalePayWayCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    
    if (self.payWayList.count > indexPath.row){
        NSDictionary *dict = self.payWayList[indexPath.row];
        cell.nameLbl.text = [dict objectForKey:@"name"];
        cell.infoLbl.text = @"";
        cell.moneyLbl.text = @"";
        
        NSString *ctype = [dict objectForKey:@"ctype"];
        NSString *type = [[dict objectForKey:@"type"] trim];
        
        NSString * path = [[NSBundle mainBundle] pathForResource:self.bundleName ofType:@"bundle"];
        UIImage *icon = [UIImage imageWithContentsOfFile:[path stringByAppendingPathComponent:@"payicon"]];
        icon = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
        [cell.iconImgV setImageUrlStr:[dict objectForKey:@"iconurl"] WithPlaceholder:icon];
        
        if ([ctype integerValue] == 1){
            //第三方支付
            for (WPReceiptType *receipt in self.wpOrder.receiptArray) {
                if ([type isEqualToString:@"alipay"] && [receipt.type isEqualToString:@"alipay"]){
                    //支付宝
                    cell.moneyLbl.text = receipt.money;
                    cell.infoLbl.text = receipt.info;
                }else if ([type isEqualToString:@"weixin"] && [receipt.type isEqualToString:@"weixin"]){
                    //微信
                    cell.moneyLbl.text = receipt.money;
                    cell.infoLbl.text = receipt.info;
                }else if ([type isEqualToString:@"lhq"] && [receipt.type isEqualToString:@"lhq"]){
                    //邻花钱
                    cell.moneyLbl.text = receipt.money;
                    cell.infoLbl.text = receipt.info;
                }else{
                    //其他
                }
            }
        }else if([ctype integerValue] == 4){
            //虚拟货币支付
            BOOL needChange = YES;
            for (WPReceiptType *receipt in self.wpOrder.receiptArray) {
                if ([receipt.atid integerValue] == [[dict objectForKey:@"atid"] integerValue]){
                    cell.moneyLbl.text = receipt.money;
                    cell.infoLbl.text = receipt.info;
                    needChange = NO;
                }
            }
            //按照汇率转换
            if (needChange){
                CGFloat moneyF = [self.defaultReceiptType.money floatValue] / [[dict objectForKey:@"rate"] floatValue];
                cell.moneyLbl.text = [NSString stringWithFormat:@"%.2f",moneyF];
            }
        }else{
        }
        
        if (self.selectedIndex.row == indexPath.row){
            UIImage *img = [UIImage imageWithContentsOfFile:[path stringByAppendingPathComponent:@"choose_blue.png"]];
            img = [img imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
            [cell.selectedBtn setImage:img forState:UIControlStateNormal];
            self.payWay = dict;
            
            //显示支付信息
            [self setupTableHeadViewWithName:cell.nameLbl.text Money:cell.moneyLbl.text Content:cell.infoLbl.text];
            //显示支付按钮
            self.payBtn.hidden = NO;
        }else{
            UIImage *img = [UIImage imageWithContentsOfFile:[path stringByAppendingPathComponent:@"choose_gray"]];
            img = [img imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
            [cell.selectedBtn setImage:img forState:UIControlStateNormal];
        }
        
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    
    return 60;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.payWayList.count > indexPath.row){
        NSDictionary *dict = self.payWayList[indexPath.row];
        self.payWay = [NSDictionary dictionaryWithDictionary:dict];
        self.selectedIndex = indexPath;
        [self.tableView reloadData];
    }
    
}


#pragma mark - 获取预支付订单
- (void)getPreparePayOrderPayWay{
    //判断token是否失效
    if (![self isLocalTokenCanUse]){
        [self getToken:self.wpOrder from:2];
        return;
    }
    
    NSString *atid = [self.payWay objectForKey:@"atid"];
    NSString *ctype = [self.payWay objectForKey:@"ctype"];
    NSString *type = [[self.payWay objectForKey:@"type"] trim];
    
    NSString *orgtype;
    NSString *orgaccountno;
    NSString *desttype;
    NSString *destaccountno;
    
    NSString *money = @"0";
    
    if ([ctype integerValue] == 1){
        //第三方支付
        orgtype = @"0";
        orgaccountno = @"0";
        
        for (WPReceiptType *receipt in self.wpOrder.receiptArray) {
            if ([type isEqualToString:@"alipay"] && [receipt.type isEqualToString:@"alipay"]){
                //支付宝
                money = receipt.money;
                desttype = receipt.atid;
                destaccountno = receipt.ano;
            }else if ([type isEqualToString:@"weixin"] && [receipt.type isEqualToString:@"weixin"]){
                //微信
                money = receipt.money;
                desttype = receipt.atid;
                destaccountno = receipt.ano;
            }else if ([type isEqualToString:@"lhq"] && [receipt.type isEqualToString:@"lhq"]){
                //邻花钱
                money = receipt.money;
                desttype = receipt.atid;
                destaccountno = receipt.ano;
            }else{
                //其他
            }
        }
    }else if([ctype integerValue] == 4){
        //虚拟货币支付
        
        orgtype = atid;
        orgaccountno = [self.payWay objectForKey:@"cano"];
        
        BOOL needChange = YES;
        for (WPReceiptType *receipt in self.wpOrder.receiptArray) {
            if ([receipt.atid integerValue] == [atid integerValue]){
                desttype = receipt.atid;
                destaccountno = receipt.ano;
                money = receipt.money;
                needChange = NO;
            }
        }
        //按照汇率转换
        if (needChange){
            CGFloat moneyF = [self.defaultReceiptType.money floatValue] / [[self.payWay objectForKey:@"rate"] floatValue];
            money = [NSString stringWithFormat:@"%.2f",moneyF];
            desttype = self.defaultReceiptType.atid;
            destaccountno = self.defaultReceiptType.ano;
        }
        
        
        //        if ([type isEqualToString:@"fanpiao"]){
        //            //全国饭票
        //
        //            BOOL needChange = YES;
        //            for (WPReceiptType *receipt in self.wpOrder.receiptArray) {
        //                if ([receipt.atid integerValue] == [atid integerValue]){
        //                    money = receipt.money;
        //                    needChange = NO;
        //                }
        //            }
        //            //按照汇率转换
        //            if (needChange){
        //                CGFloat moneyF = [self.defaultReceiptType.money floatValue] / [[payWay objectForKey:@"rate"] floatValue];
        //                money = [NSString stringWithFormat:@"%.2f",moneyF];
        //            }
        //        }else if ([type isEqualToString:@"lfanpiao"]){
        //            //地方饭票
        //            BOOL needChange = YES;
        //            for (WPReceiptType *receipt in self.wpOrder.receiptArray) {
        //                if ([receipt.atid integerValue] == [atid integerValue]){
        //                    money = receipt.money;
        //                    needChange = NO;
        //                }
        //            }
        //            //按照汇率转换
        //            if (needChange){
        //                CGFloat moneyF = [self.defaultReceiptType.money floatValue] / [[payWay objectForKey:@"rate"] floatValue];
        //                money = [NSString stringWithFormat:@"%.2f",moneyF];
        //            }
    }else{
        
    }
    
    //    if ([atid integerValue] == 4 || [atid integerValue] == 5 || [atid integerValue] == 31){
    //        //第三方支付（微信，支付宝，双乾），dict为收款方信息
    //        orgtype = @"0";
    //        orgaccountno = @"0";
    //        desttype = atid;
    //        destaccountno = [payWay objectForKey:@"pano"];
    //        money = @"100";
    //    }else{
    //        //非第三方支付，dict为付款方信息
    //        orgtype = atid;
    //        orgaccountno = [payWay objectForKey:@"cano"];
    //
    //        BOOL needChange = YES;
    //        for (WPReceiptType *receipt in self.wpOrder.receiptArray) {
    //            if ([receipt.atid integerValue] == [atid integerValue]){
    //                desttype = atid;
    //                destaccountno = receipt.ano;
    //                money = receipt.money;
    //                needChange = NO;
    //            }
    //        }
    //        //按照汇率转换
    //        if (needChange){
    //            CGFloat moneyF = [self.defaultReceiptType.money floatValue] / [[payWay objectForKey:@"rate"] floatValue];
    //            money = [NSString stringWithFormat:@"%0.2f",moneyF];
    //            desttype = self.defaultReceiptType.atid;
    //            destaccountno = self.defaultReceiptType.ano;
    //        }
    //    }
    
    
    
    NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@",PrePayUrl,self.access_token]];
    NSMutableURLRequest * postRequest=[NSMutableURLRequest requestWithURL:url];
    NSDictionary* dict = @{
                           @"money"  : money,
                           @"orderno"  : self.wpOrder.orderno,
                           @"content"  : self.wpOrder.content,
                           @"orgtype"  : orgtype,
                           @"orgaccountno"  : orgaccountno,
                           @"desttype"  : desttype,
                           @"destaccountno"  : destaccountno,
                           @"detail"  : self.wpOrder.detail,
                           @"starttime"  : self.wpOrder.starttime,
                           @"stoptime"  : self.wpOrder.stoptime,
                           @"callback"  : self.wpOrder.callback,
                           @"remoteip"  : self.wpOrder.remoteip,
                           @"fixedorgmoney" : self.wpOrder.fixedorgmoney,
                           //                           @"orgsubaccount" : [NSString dictionaryToJson:self.wpOrder.orgsubaccount],
                           //                           @"destsubaccount" : [NSString dictionaryToJson:self.wpOrder.destsubaccount]
                           @"orgsubaccount" : @"",
                           @"destsubaccount" : @""
                           };
    NSData* data = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:nil];
    NSString *bodyData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    [postRequest setHTTPBody:[NSData dataWithBytes:[bodyData UTF8String] length:strlen([bodyData UTF8String])]];
    [postRequest setHTTPMethod:@"POST"];
    [postRequest setValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:postRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
            NSLog(@"%@",result);
            NSDictionary *content = [result objectForKey:@"content"];
            if ([content isKindOfClass:[NSDictionary class]]){
                if (result != nil && content != nil && result.allKeys.count > 0 && content.allKeys.count > 0 && [[result objectForKey:@"code"] integerValue] == 0){
                    NSDictionary *payinfo = [content objectForKey:@"payinfo"];
                    if (payinfo != nil && payinfo.allKeys.count > 0){
                        //支付订单
                        [self payAction:payinfo Money:money];
                    }else{
                        [MBProgressHUD showMessage:[NSString stringWithFormat:@"%@",[result objectForKey:@"message"]] toView:self.view];
                    }
                }else{
                    [MBProgressHUD showMessage:[NSString stringWithFormat:@"%@",[result objectForKey:@"message"]] toView:self.view];
                }
            }else{
                [MBProgressHUD showMessage:[NSString stringWithFormat:@"%@",[result objectForKey:@"message"]] toView:self.view];
            }
            
        });
    }];
}


- (void)payAction:(NSDictionary *)payInfo Money:(NSString *)money{
    NSString *payType = [[payInfo objectForKey:@"paytype"] trim];
    
    if ([payType isEqualToString:@"weixin"]){
        //微信支付
        [self wxPayAction:payInfo];
    }else if ([payType isEqualToString:@"alipay"]){
        //支付宝支付
        [self aliPayAction:payInfo];
    }else if ([payType isEqualToString:@"lhq"]){
        //双乾支付
        [self lhqPayAction:payInfo Money:money];
    }else if ([payType isEqualToString:@"fanpiao"]){
        //全国饭票支付
        [self fanpiaoPayAction:payInfo];
    }else if ([payType isEqualToString:@"lfanpiao"]){
        //地方饭票支付
        [self lfanpaioPayAction:payInfo];
    }else{
        [MBProgressHUD showMessage:@"未知支付方式" toView:self.view];
    }
}

#pragma mark - 支付

//微信支付
- (void)wxPayAction:(NSDictionary *)payInfo{
    /**
     {
     code = 0;
     content =     {
     payinfo =         {
     appId = wx42967af88ec99501;
     nonceStr = cyJpTi1rdzigZeHa;
     packageValue = "Sign=WXPay";
     partnerId = 1294012101;
     paytype = weixin;
     prepayId = wx20170310165751e4a58a71c10809819678;
     sign = 7595124F39B16B51398294946CC3BA19;
     timeStamp = 1489136271;
     tno = "1703_201703101657511b3244aebbf81";
     };
     };
     contentEncrypt = "";
     message = "";
     }
     */
    NSString *appId = [payInfo objectForKey:@"appId"];
    NSString *partnerId = [payInfo objectForKey:@"partnerId"];
    NSString *prepayId = [payInfo objectForKey:@"prepayId"];
    NSString *nonceStr = [payInfo objectForKey:@"nonceStr"];
    NSString *timeStamp = [payInfo objectForKey:@"timeStamp"];
    NSString *packageValue = [payInfo objectForKey:@"packageValue"];
    NSString *sign = [payInfo objectForKey:@"sign"];
    
    
    if ([WXApi isWXAppInstalled]){
        //调起微信支付
        PayReq* req             = [[PayReq alloc] init];
        req.openID              = appId;
        req.partnerId           = partnerId;
        req.prepayId            = prepayId;
        req.nonceStr            = nonceStr;
        req.timeStamp           = [timeStamp intValue];
        req.package             = packageValue;
        req.sign                = sign;
        
        [WXApi sendReq:req];
        
    }else{
        [MBProgressHUD showMessage:@"请安装微信" toView:self.view];
    }
    
}

/**
 微信回调
 */
- (void)onResp:(BaseResp *)resp{
    if ([resp isKindOfClass:[PayResp class]]){
        switch (resp.errCode) {
            case WXSuccess:
                //支付成功
                self.payResult = @{
                                   @"code" : @"0",
                                   @"message" : @"支付成功"
                                   };
                [self dealPayResult];
                break;
            case WXErrCodeUserCancel:
                //客户取消操作
                self.payResult = @{
                                   @"code" : @"1000",
                                   @"message" : @"客户取消操作"
                                   };
                [self dealPayResult];
                break;
            default:
                self.payResult = @{
                                   @"code" : @"1005",
                                   @"message" : resp.errStr ? resp.errStr : @"支付失败"
                                   };
                [self dealPayResult];
                break;
        }
    }
}



//支付宝支付
- (void)aliPayAction:(NSDictionary *)payInfo{
    NSString *orderStr = [payInfo objectForKey:@"orderInfo"];
    
    //支付宝
    [[AlipaySDK defaultService] payOrder:orderStr fromScheme:self.aliSchemel callback:^(NSDictionary *resultDic) {
        //处理支付结果
        [self aliPayResult:resultDic];
    }];
}

- (void)aliPayResult:(NSDictionary *)resultDic{
    if ([[resultDic objectForKey:@"resultStatus"] isEqualToString:@"9000"]){
        //支付成功
        self.payResult = @{
                           @"code" : @"0",
                           @"message" : @"支付成功"
                           };
        [self dealPayResult];
    }else if ([[resultDic objectForKey:@"resultStatus"] isEqualToString:@"6001"]){
        //支付取消
        self.payResult = @{
                           @"code" : @"1000",
                           @"message" : @"支付取消"
                           };
        [self dealPayResult];
    }else{
        //支付失败
        NSString *memo = [resultDic objectForKey:@"memo"];
        self.payResult = @{
                           @"code" : @"1005",
                           @"message" : [memo isNotNull] ? memo : @"支付失败"
                           };
        [self dealPayResult];
    }
}

//双乾支付
- (void)lhqPayAction:(NSDictionary *)payInfo Money:(NSString *)money{
    NSString *merNo = [payInfo objectForKey:@"merNo"];
    NSString *tno = [payInfo objectForKey:@"tno"];
    
    NSDictionary *dic = @{
                          @"userNo" : [NSString stringWithFormat:@"%@%@%@",merNo,self.wpOrder.pno,self.wpOrder.userId],                         // 用户编号
                          @"merNo" : merNo,                   // 商户编号
                          @"mobile" : self.wpOrder.mobile,                // 用户手机号
                          @"orderNum" : tno,      // 交易订单号
                          @"amount" : money,                        // 产生的交易金额
                          @"orderType" :@"CJ01",                       // 支付方式
                          @"goods_desc" : self.wpOrder.content,  // 商品说明
                          @"goods_name" : self.wpOrder.content,                    //商品名称
                          @"userName" : self.wpOrder.userName,
                          @"province" : self.wpOrder.province,
                          @"city" : self.wpOrder.city,
                          @"block" : self.wpOrder.block,
                          @"gbName" : self.wpOrder.gbName
                          };
    
    [ControllerActivity setSDKServiceURL:@"http://218.4.234.150:10080/creditsslpay/"];
    [ControllerActivity setParams:dic signInfoBlock:^NSString *(NSString *secretKey, NSString *signInfo, int isSignWithPrivateKey) {
        if (isSignWithPrivateKey == 0) {
            return [self decryWithPriviteKey:secretKey origaStr:signInfo];     // 解密
        } else if (isSignWithPrivateKey == 1){
            return [self encryWithPublicKey:secretKey origaStr:signInfo];      // 加密
        } else {
            return [self doRsaPriviteKey:secretKey origalStr:signInfo];                   // 签名
        }
    } resultBlock:^(NSDictionary *result) {
        NSLog(@"%@", result);
        if ([result.allKeys containsObject:@"OrderState"]) {
            if ([[result objectForKey:@"OrderState"] integerValue] == 0){
                self.payResult = @{
                                   @"code" : @"0",
                                   @"message" : @"支付成功"
                                   };
                [self dealPayResult];
            }else{
                self.payResult = @{
                                   @"code" : [result objectForKey:@"OrderState"],
                                   @"message" : [result objectForKey:@"StateExplain"]
                                   };
                [self dealPayResult];
            }
            
        } else if ([result.allKeys containsObject:@"resultCode"]) {
            self.payResult = @{
                               @"code" : [result objectForKey:@"resultCode"],
                               @"message" : [result objectForKey:@"resMess"]
                               };
            [self dealPayResult];
            
        } else {
            
        }
    }];
    
}

//全国饭票支付
- (void)fanpiaoPayAction:(NSDictionary *)payInfo{
    
}

//地方饭票支付
- (void)lfanpaioPayAction:(NSDictionary *)payInfo{
    
}


#pragma mark - 双乾支付加密解密过程
// 私钥签名
-(NSString*)doRsaPriviteKey:(NSString *)priviteKey origalStr:(NSString*)string
{
    id<DataSigner> signer;
    signer = CreateRSADataSigner(priviteKey);
    NSString *signedString = [signer signString:string];
    return signedString;
}

// 公钥验签
- (BOOL)verifyRsaPublicKey:(NSString *)publicKey origalStr:(NSString *)string signStr:(NSString *)signString
{
    id<DataVerifier> verifySigner;
    verifySigner = CreateRSADataVerifier(publicKey);
    bool verifyRs = [verifySigner verifyString:string withSign:signString];
    return verifyRs;
}

//公钥加密数据
-(NSString *)encryWithPublicKey:(NSString *)publicKey origaStr:(NSString *)string
{
    //生成一个随机的8位字符串，作为des加密数据的key,对数据进行des加密，对加密后的数据用公钥再进行一次rsa加密
    NSString *encryptString = [RSAUtil encryptString: string publicKey:publicKey];
    return encryptString;
}

//私钥解密数据
-(NSString *)decryWithPriviteKey:(NSString *)priviteKey origaStr:(NSString *)string
{
    return [RSAUtil decryptString:string privateKey:priviteKey];
}



@end
