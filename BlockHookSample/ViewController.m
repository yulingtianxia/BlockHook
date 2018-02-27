//
//  ViewController.m
//  BlockHookSample
//
//  Created by 杨萧玉 on 2018/2/26.
//  Copyright © 2018年 杨萧玉. All rights reserved.
//

#import "ViewController.h"
#import "BHToken.h"
#import <objc/runtime.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    int (^block)(int, int) = ^(int x, int y) { NSLog(@"I'm here!"); return x + y; };
    
    BHToken *token = [block block_hookWithMode:BlockHookModeAfter usingBlock:^(BHToken *token, int x, int y){
        NSLog(@"after x:%d y:%d ret:%d", x, y, *(int *)(token.retValue));
    }];

    BHToken *token1 = [block block_hookWithMode:BlockHookModeBefore usingBlock:^(id token){
        NSLog(@"before token:%@", token);
    }];
    
    [token block_hookWithMode:BlockHookModeBefore usingBlock:^() {
        
    }];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        int ret = block(3, 5);
        NSLog(@"result: %d", ret);
        [token remove];
        [token1 remove];
    });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
