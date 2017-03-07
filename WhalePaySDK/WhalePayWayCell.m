//
//  WhalePayWayCell.m
//  WhalePaySDK
//
//  Created by 李勇 on 2017/3/4.
//  Copyright © 2017年 liyong. All rights reserved.
//

#import "WhalePayWayCell.h"

@implementation WhalePayWayCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event{
    return self;
}

@end
