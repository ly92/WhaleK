//
//  WhalePayWayCell.h
//  WhalePaySDK
//
//  Created by 李勇 on 2017/3/4.
//  Copyright © 2017年 liyong. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface WhalePayWayCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UIImageView *iconImgV;
@property (weak, nonatomic) IBOutlet UILabel *nameLbl;
@property (weak, nonatomic) IBOutlet UILabel *moneyLbl;
@property (weak, nonatomic) IBOutlet UILabel *infoLbl;
@property (weak, nonatomic) IBOutlet UIButton *selectedBtn;

@end
