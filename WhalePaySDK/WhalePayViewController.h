//
//  WhalePayViewController.h
//  WhalePaySDK
//
//  Created by 李勇 on 2017/3/2.
//  Copyright © 2017年 liyong. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>



#undef  singleton
#define singleton( __class ) \
property (nonatomic, readonly) __class * sharedInstance; \
- (__class *)sharedInstance; \
+ (__class *)sharedInstance;

#undef  def_singleton
#define def_singleton( __class ) \
dynamic sharedInstance; \
- (__class *)sharedInstance \
{ \
return [__class sharedInstance]; \
} \
+ (__class *)sharedInstance \
{ \
static dispatch_once_t once; \
static __strong id __singleton__ = nil; \
dispatch_once( &once, ^{ __singleton__ = [[__class alloc] init]; } ); \
return __singleton__; \
}

#define RGBCOLOR(r,g,b) \
[UIColor colorWithRed:r/255.f green:g/255.f blue:b/255.f alpha:1.f]

#define SCRREN_HEIGHT [UIScreen mainScreen].bounds.size.height
#define SCRREN_WIDTH [UIScreen mainScreen].bounds.size.width


/**
 {
 code
 message
 }
 
 code	message
 
 0      “”
 1000	“客户取消操作”
 1001	“签名信息失败”
 1002	“数据异常，交易失败”
 1003	“数据异常，请求失败”
 1004	“必填参数缺少或异常”
 */
typedef void (^AKPayCompletion)(NSDictionary *result);

//收款账号信息
@interface WPReceiptType : NSObject
@property (copy, nonatomic) NSString *atid;//收款通道类型
@property (copy, nonatomic) NSString *name;//收款通道名称
@property (copy, nonatomic) NSString *ano;//收款帐号编号
@property (copy, nonatomic) NSString *money;//此收款通道应收金额
@property (copy, nonatomic) NSString *info;//附加信息
@property (copy, nonatomic) NSString *isDefault;//是否为默认收款账号
@property (copy, nonatomic) NSString *ctype;//通道类型 1:第三方通道  4:虚拟货币通道
@property (copy, nonatomic) NSString *type;//饭票类型 fanpiao：全国饭票   lfanpiao：地方饭票
@end

@interface WPOrder : NSObject
//require  正常使用支付功能必须输入的信息
@property (nonatomic, copy) NSString *pno;//平台账号（本app相对于奥科公司对应的ID号）
@property (copy, nonatomic) NSString *cno;//用户针对金融平台中当前应用的身份
/**
 获取的支付方式存在于此数组中才可以显示，微信支付宝双乾的pano为0，其他支付方式值为收款帐号编号
 */
@property (strong, nonatomic) NSArray<NSNumber *> *payTypeArray;//app支持的支付通道
/**
 获取的支付方式存在于此数组中才可以显示，微信支付宝双乾的pano为0，其他支付方式值为收款帐号编号
 */
@property (strong, nonatomic) NSArray<WPReceiptType *> *receiptArray;//app提供的收款通道

@property (copy, nonatomic) NSString *orderno;//接入方生成的订单编号
@property (nonatomic, copy) NSString *content;//交易说明（显示给用户的内容）
@property (copy, nonatomic) NSString *userId;//本app里面当前用户对应的ID号


//option   可选的信息
/*
 下面两个属性---保留字段
 */
@property (strong, nonatomic) NSDictionary *orgsubaccount;//支付账号子账号修改信息
@property (strong, nonatomic) NSDictionary *destsubaccount;//收款账号子账号修改信息
/*
 当发生跨币种汇兑交易时，金融平台会自动根据汇率计算交易金额。转账时一般需要固定支付金额，避免多扣款；消费时一般不固定，确保收款正确。
 */
@property (copy, nonatomic) NSString *fixedorgmoney;//支付金额固定，0不固定，1固定
/*
 需要使用微信支付的时候必填写此参数
 */
@property (nonatomic, copy) NSString *remoteip;//调用方ip地址

@property (copy, nonatomic) NSString *detail;//交易明细
@property (nonatomic, copy) NSString *starttime;//交易生效时间
@property (nonatomic, copy) NSString *stoptime;//交易失效时间
@property (nonatomic, copy) NSString *callback;//业务系统回调
@property (copy, nonatomic) NSString *mobile;//本app里面当前用户的手机号
@property (copy, nonatomic) NSString *userName;//本app里面当前用户对应的用户名
@property (copy, nonatomic) NSString *city;//市
@property (copy, nonatomic) NSString *province;//省
@property (copy, nonatomic) NSString *block;//行政区
@property (copy, nonatomic) NSString *gbName;//小区名称

@end



@interface WhalePayViewController : UIViewController

//资源文件名称
@property (copy, nonatomic) NSString *bundleName;//


//单例
@singleton( WhalePayViewController );

/**
 支付调用接口(支付宝/微信)
 
 @param wpOrder WPOrder 对象(JSON 格式字符串 或 NSDictionary)
 @param viewController 当前控制器，做跳转用
 @param completion 支付结果回调 Block
 */
- (void)createPayment:(WPOrder *)wpOrder viewController:(UIViewController *)viewController withCompletion:(AKPayCompletion)completion;

/**
 *  回调结果接口(支付宝/微信/测试模式)
 *
 *  @param url              结果url
 *  @param completion  支付结果回调 Block，保证跳转支付过程中，当 app 被 kill 掉时，能通过这个接口得到支付结果
 *
 *  @return                 当无法处理 URL 或者 URL 格式不正确时，会返回 NO。
 */
- (BOOL)handleOpenURL:(NSURL *)url withCompletion:(AKPayCompletion)completion;

/**
 *  回调结果接口(支付宝/微信/测试模式)
 *
 *  @param url                结果url
 *  @param sourceApplication  源应用 Bundle identifier
 *  @param completion    支付结果回调 Block，保证跳转支付过程中，当 app 被 kill 掉时，能通过这个接口得到支付结果
 *
 *  @return                   当无法处理 URL 或者 URL 格式不正确时，会返回 NO。
 */
- (BOOL)handleOpenURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication withCompletion:(AKPayCompletion)completion;

/**
 *  打开app时注册 包含：1.注册APPID（微信）2.appkey 3.appsecret
 *  key         value
 *  aliSchemel  支付宝schemel
 *  wxAppid     微信支付ID，例如“wx42967af88ec67866”
 *  appkey      接入应用新增成功后，系统将自动生成20位的appkey和32位的appsercet
 *  appsecret   接入应用新增成功后，系统将自动生成20位的appkey和32位的appsercet
 */
- (void)setAppId:(NSDictionary *)dict;

@end
