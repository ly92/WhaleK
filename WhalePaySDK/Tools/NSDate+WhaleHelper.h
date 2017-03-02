//
//  NSDate+WhaleHelper.h
//  WhalePaySDK
//
//  Created by 李勇 on 2017/3/2.
//  Copyright © 2017年 liyong. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDate (WhaleHelper)
//php时间戳（时间格式的字符串转换成时间戳）
+(NSString *)phpTimestamp;
+(NSString *)phpTimestampWithDate:(NSDate *)date;

//php转换(时间戳转换成对应时间格式的字符串)
+(NSString *)longlongToDateTime:(NSString *)sender formator:(NSString *)formator;

// Retrieving intervals
- (NSInteger) minutesAfterDate: (NSDate *) aDate;
- (NSInteger) minutesBeforeDate: (NSDate *) aDate;

+ (NSDate *)dateFromString:(NSString *)string withFormat:(NSString *)format;
@end
