//
//  NSDate+WhaleHelper.m
//  WhalePaySDK
//
//  Created by 李勇 on 2017/3/2.
//  Copyright © 2017年 liyong. All rights reserved.
//

#import "NSDate+WhaleHelper.h"
#import "NSString+WhaleHelper.h"

#define D_MINUTE	60


@implementation NSDate (WhaleHelper)

+(NSString *)phpTimestamp{
    NSDate *now = [NSDate date];
    NSTimeInterval interval = [now timeIntervalSince1970];
    NSString *ts = [NSString stringWithFormat:@"%.0f",interval];
    
    return ts;
}

+(NSString *)phpTimestampWithDate:(NSDate *)date{
    NSTimeInterval interval = [date timeIntervalSince1970];
    NSString *ts = [NSString stringWithFormat:@"%.0f",interval];
    
    return ts;
}

//php转换，时间戳转换成对应的时间格式的字符串

+(NSString *)longlongToDateTime:(NSString *)sender formator:(NSString *)formator{
    if ([sender isEqualToString:@"0"]) {
        return @"";
    }
    if ([[sender stringByTrim] isEqualToString:@""] || sender == nil) {
        return @"";
    }
    
    
    if ([[formator stringByTrim] isEqualToString:@""] || formator == nil) {
        formator = @"yyyy-MM-dd HH:mm:ss";
    }
    
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:[sender longLongValue]];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:formator];
    return [dateFormatter stringFromDate:date];
}

- (NSInteger) minutesAfterDate: (NSDate *) aDate
{
    NSTimeInterval ti = [self timeIntervalSinceDate:aDate];
    return (NSInteger) (ti / D_MINUTE);
}

- (NSInteger) minutesBeforeDate: (NSDate *) aDate
{
    NSTimeInterval ti = [aDate timeIntervalSinceDate:self];
    return (NSInteger) (ti / D_MINUTE);
}

+ (NSDate *)dateFromString:(NSString *)string withFormat:(NSString *)format {
    NSDateFormatter *inputFormatter = [[NSDateFormatter alloc] init];
    [inputFormatter setDateFormat:format];
    NSDate *date = [inputFormatter dateFromString:string];
    return date;
}
@end
