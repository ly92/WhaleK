//
//  UIImageView+WhaleHelper.m
//  WhalePaySDK
//
//  Created by 李勇 on 2017/3/7.
//  Copyright © 2017年 liyong. All rights reserved.
//

#import "UIImageView+WhaleHelper.h"

@implementation UIImageView (WhaleHelper)

- (void)setImageUrlStr:(NSString *)urlStr WithPlaceholder:(UIImage *)image{
    self.image = image;
    
    
    dispatch_async([self setterQueue], ^{
        UIImage *image2;
        NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:urlStr]];
        image2 = [UIImage imageWithData:data];
        if (image2 != nil){
            dispatch_async(dispatch_get_main_queue(), ^{
                self.image = image2;
            });
        }
    });
}

- (dispatch_queue_t)setterQueue {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.whalePay", NULL);
        dispatch_set_target_queue(queue, dispatch_get_global_queue(0, 0));
    });
    return queue;
}
@end
