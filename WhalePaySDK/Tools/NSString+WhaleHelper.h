//
//  NSString+WhaleHelper.h
//  WhalePaySDK
//
//  Created by 李勇 on 2017/3/2.
//  Copyright © 2017年 liyong. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (WhaleHelper)
- (NSString *)stringByTrim;

- (NSString *)MD5Hash;

- (NSString*)trim;

- (BOOL)isNotNull;

+ (NSString*)dictionaryToJson:(NSDictionary *)dic;
@end
