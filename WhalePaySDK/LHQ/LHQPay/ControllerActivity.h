//
//  ControllerActivity.h
//  LHQPay
//
//  Created by 95epay on 16/9/1.
//  Copyright © 2016年 www.95epay.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface ControllerActivity : NSObject

/** 邻花钱测试服务器调试模式
 *  @param isEnable 默认服务器开关
 *                  当isEnable=YES时,启用测试服务器(http://218.4.234.150:88/main)
 *                  当isEnable=NO时,启用正式服务器(https://www.moneymoremore.com)
 *
 *  注意:当未使用该方法时, 默认启用正式服务器
 */
+(void)enableTestServiceURL:(BOOL)isEnable;
+(void)setSDKServiceURL:(NSString *)URL;
/** 自定义服务器
 *  @param serviceURL 用户自定义的服务器地址
 *                    (如将来默认测试服务器或正式服务器发生变动,用该方法临时配置)
 *
 *  注意:没有特殊情况, 不建议使用该方法
 */
+(void)setServiceURL:(NSString *)serviceURL;

/** 邻花钱接口调用
 *  @param dic 用户提供的NSDictionary数据
 *  @param signBlock 用户签名或加密字符串block:
 *         block的参数中signInfo是需要用户进行处理的字符串数据,isSignWithPrivateKey用来判断签名或者加密
 *         当isSignWithPrivateKey=YES时,用户需要对signInfo做私钥签名处理,
 *         当isSignWithPrivateKey=NO时,用户需要对signInfo做公钥加密处理
 */
+(void)setParams:(NSDictionary *)dic
   signInfoBlock:(NSString *(^)(NSString *secretKey, NSString *signInfo, int isSignWithPrivateKey))signBlock;

/** 邻花钱SDK接口调用
 *  @param dic 用户提供的NSDictionary数据
 *  @param signBlock 用户签名或加密字符串block:
 *         block的参数中signInfo是需要用户进行处理的字符串数据,isSignWithPrivateKey用来判断签名或者加密
 *         当isSignWithPrivateKey=YES时,用户需要对signInfo做私钥签名处理,
 *         当isSignWithPrivateKey=NO时,用户需要对signInfo做公钥加密处理
 *  @param resultBlock 用户事件回调block,返回目标事件的数据结果
 *         (如用户进行充值事件时,当用户点击充值按钮并从服务器成功返回数据后,执行该block.
 *         用户可根据block提供的NSdictionary参数,自行进行下一步结果处理)
 */
+(void)setParams:(NSDictionary *)dic
   signInfoBlock:(NSString *(^)(NSString *secretKey, NSString *signInfo, int isSignWithPrivateKey))signBlock
     resultBlock:(void (^)(NSDictionary *result))resultBlock;

@end
